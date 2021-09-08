---
title: "Kubernetes Informer 源码分析"
date: 2021-03-08T01:56:30+08:00
lastmod: 2021-03-08T01:56:30+08:00
draft: false
keywords: ["Client-go", "informer", "Kubernetes"]
description: "Kubernetes Informer 源码分析"
tags: ["Client-go", "informer", "Kubernetes"]
categories: ["Kubernetes"]
author: "Joe"

# You can also close(false) or open(true) something for this content.
# P.S. comment can only be closed
comment: true
toc: true
autoCollapseToc: false
# You can also define another contentCopyright. e.g. contentCopyright: "This is another copyright."
contentCopyright: <a rel="license noopener" href="https://creativecommons.org/licenses/by-nc-nd/4.0/deed.zh" target="_blank">CC BY-NC-ND 4.0</a>
reward: false
mathjax: false
---

<!-- Abstract -->



<!--more-->



<!-- Content -->
# Informer 是什么
在 k8s 中，所有的数据流通都要经过 API-Server，那么和 API-Server 的通信就很频繁了。在此基础上，发展出了 client-go 这样的库，通过 client-go，我们可以很方便地访问 k8s 资源。而在 client-go 中，负责和 API-Server 通信的，则是 Informer。

# 为什么要 Informer
- 缓存资源，减少不必要的对 API-Server 的请求，提高性能。
- 保证资源事件正确传达，达到最终一致性。

# Informer 原理
1. 通过 List/Watch 获取 API-Server 中的资源，存储到本地缓存中，通过 `Lister` 提供访问。
2. 提供事件注册，如果监听到对应资源事件的变化，则根据对应事件的 `EventHandler`，执行回调。

List/Watch -> 本地缓存 -> 提供访问/事件回调

![Informer 运行原理|600](https://images.adevjoe.com/2021-09-08-ZyLSWJ.jpg)
（图来自：[itnext.io](https://itnext.io/how-to-create-a-kubernetes-custom-controller-using-client-go-f36a7a7536cc)）

关键组件：
- Reflector
- Delta FIFO
- HandleDeltas
- Indexer
- ThreadSafeStore

对应组件基本都在 `tools/cache` 包中。以下代码为 `client-go` `v0.19.0` 版本。

## Informer 初始化
每种资源都有自己的 Informer，官方资源的 Informer 已经在 client-go 中自带了，在 `informers` 包中。我们一般会通过 `informers.NewSharedInformerFactory` 来创建 Informers，这样在调用不同的资源时，每种资源只会用一个 Informer，本地缓存的资源数据也会是同一份。

### Shared Informer 初始化
```go
func NewSharedInformerFactoryWithOptions(client kubernetes.Interface, defaultResync time.Duration, options ...SharedInformerOption) SharedInformerFactory {
	factory := &sharedInformerFactory{
		client:           client,
		namespace:        v1.NamespaceAll,
		defaultResync:    defaultResync,
		informers:        make(map[reflect.Type]cache.SharedIndexInformer),
		startedInformers: make(map[reflect.Type]bool),
		customResync:     make(map[reflect.Type]time.Duration),
	}

	// Apply all options
	for _, opt := range options {
		factory = opt(factory)
	}

	return factory
}
```
通过 defaultResync 设置同步周期，初始化 informers map，为了之后创建对应类型的 Informer。

### 特定资源 Informer 初始化
通过调用如下的接口，可以初始化对应资源的 Informer。
![informer|600](https://images.adevjoe.com/2021-09-08-YHtXYy.png)

如：`sharedInformers.Core().V1().Pods().Informer()`

每个资源的 Informer 方法又会去调用 `InformerFor` 方法。
```go
func (f *storageClassInformer) Informer() cache.SharedIndexInformer {
	return f.factory.InformerFor(&storagev1.StorageClass{}, f.defaultInformer)
}
```
InformerFor 位于 `informers/factory.go` 中。
```go
func (f *sharedInformerFactory) InformerFor(obj runtime.Object, newFunc internalinterfaces.NewInformerFunc) cache.SharedIndexInformer {
	f.lock.Lock()
	defer f.lock.Unlock()

	informerType := reflect.TypeOf(obj)
	informer, exists := f.informers[informerType]
	if exists {
		return informer
	}

	resyncPeriod, exists := f.customResync[informerType]
	if !exists {
		resyncPeriod = f.defaultResync
	}

	informer = newFunc(f.client, resyncPeriod)
	f.informers[informerType] = informer

	return informer
}
```
初始化 Informer 时，如果 informer 已经存在则直接返回列表中的 informer，否则会创建一个 Informer 放入 sharedInformers 的 informers 的列表中。
创建 Informer 会初始化一个 ListWatch，这里会调用 client 的 `List` 和 `Watch` 方法。
```go
func NewFilteredStorageClassInformer(client kubernetes.Interface, resyncPeriod time.Duration, indexers cache.Indexers, tweakListOptions internalinterfaces.TweakListOptionsFunc) cache.SharedIndexInformer {
	return cache.NewSharedIndexInformer(
		&cache.ListWatch{
			ListFunc: func(options metav1.ListOptions) (runtime.Object, error) {
				if tweakListOptions != nil {
					tweakListOptions(&options)
				}
				return client.StorageV1().StorageClasses().List(context.TODO(), options)
			},
			WatchFunc: func(options metav1.ListOptions) (watch.Interface, error) {
				if tweakListOptions != nil {
					tweakListOptions(&options)
				}
				return client.StorageV1().StorageClasses().Watch(context.TODO(), options)
			},
		},
		&storagev1.StorageClass{},
		resyncPeriod,
		indexers,
	)
}
```
调用 `cache.NewSharedIndexInformer` 就是初始化 Informer 最终的地方了。这里会初始化需要的 `Indexer` 和 `listerWatcher`。`NewIndexer` 会初始化一个线程安全的存储，我们的资源缓存在这。为了保证存储是线程安全的，我们需要对 `Get` `List` 获取到的资源做到 `ReadOnly`，如果要修改，可以先 copy 一份，不要修改指针里的值。Indexer 默认带有一个命名空间索引，我们可以根据命名空间拿到对应资源。通过添加 Index 方法，也可以自定义索引，然后根据自定义索引获取资源。这里的 indexers 和 indices 看起来是非常绕的，但是增加了索引的扩展性。
```go
func NewSharedIndexInformer(lw ListerWatcher, exampleObject runtime.Object, defaultEventHandlerResyncPeriod time.Duration, indexers Indexers) SharedIndexInformer {
	realClock := &clock.RealClock{}
	sharedIndexInformer := &sharedIndexInformer{
		processor:                       &sharedProcessor{clock: realClock},
		indexer:                         NewIndexer(DeletionHandlingMetaNamespaceKeyFunc, indexers),
		listerWatcher:                   lw,
		objectType:                      exampleObject,
		resyncCheckPeriod:               defaultEventHandlerResyncPeriod,
		defaultEventHandlerResyncPeriod: defaultEventHandlerResyncPeriod,
		cacheMutationDetector:           NewCacheMutationDetector(fmt.Sprintf("%T", exampleObject)),
		clock:                           realClock,
	}
	return sharedIndexInformer
}
```

## Informer 启动
初始化 Informer 之后，调用 `sharedInformerFactory.Start()` 启动整个 shardInformer，这里会根据 startedInformers 中来判断 `Informers` 列表中的 `Informer` 是否启动。
```go
// Start initializes all requested informers.
func (f *sharedInformerFactory) Start(stopCh <-chan struct{}) {
	f.lock.Lock()
	defer f.lock.Unlock()

	for informerType, informer := range f.informers {
		if !f.startedInformers[informerType] {
			go informer.Run(stopCh)
			f.startedInformers[informerType] = true
		}
	}
}
```

每个 Informer 通过 `Run()` 来启动，大概有以下几个步骤。
1. 初始化 DeltaFIFO
2. 初始化 Controller 参数（这里是 Controller 低级封装）
3. 创建 controller
4. 启动 cacheMutationDetector
5. 启动 processor
6. 运行 controller

```go
func (s *sharedIndexInformer) Run(stopCh <-chan struct{}) {
	fifo := NewDeltaFIFOWithOptions(DeltaFIFOOptions{
		KnownObjects:          s.indexer,
		EmitDeltaTypeReplaced: true,
	})

	cfg := &Config{
		Queue:            fifo,
		ListerWatcher:    s.listerWatcher,
		ObjectType:       s.objectType,
		FullResyncPeriod: s.resyncCheckPeriod,
		RetryOnError:     false,
		ShouldResync:     s.processor.shouldResync,

		Process:           s.HandleDeltas,
		WatchErrorHandler: s.watchErrorHandler,
	}

	func() {
		s.startedLock.Lock()
		defer s.startedLock.Unlock()

		s.controller = New(cfg)
		s.controller.(*controller).clock = s.clock
		s.started = true
	}()

	// Separate stop channel because Processor should be stopped strictly after controller
	processorStopCh := make(chan struct{})
	var wg wait.Group
	defer wg.Wait()              // Wait for Processor to stop
	defer close(processorStopCh) // Tell Processor to stop
	wg.StartWithChannel(processorStopCh, s.cacheMutationDetector.Run)
	wg.StartWithChannel(processorStopCh, s.processor.run)

	defer func() {
		s.startedLock.Lock()
		defer s.startedLock.Unlock()
		s.stopped = true // Don't want any new listeners
	}()
	s.controller.Run(stopCh)
}
```

### DeltaFIFO
DeltaFIFO 跟同一个包里面的 FIFO 很像，都是先进先出的队列模型，但是有两处不同。第一，DeltaFIFO 中保存的值不是 `Object`，而是 Delta 列表，列表中 index 0 的元素为最老的元素，每个 Delta 元素中包含 `Object` 和 `DeltaType`，这个类型也就是资源变更的类型，添加删除之类的。第二个不同是 DeltaFIFO 额外有两种入队的方式(`Replaced` 和 `Sync`)。一般 Watch 出错了，就会用 `Replaced` 来重新构建队列，`Sync` 则是由同步周期带来的数据。DeltaFIFO 也是生产者消费者模型，生产者是 Reflector，它负责把 List/Watch 的值传给 DeltaFIFO，消费者则是 Pop()。每种资源入队都会调用 `queueActionLocked`，用来给对象入队，通过 deltas 可以保证入队的顺序性和唯一性。
```go
// queueActionLocked appends to the delta list for the object.
// Caller must lock first.
func (f *DeltaFIFO) queueActionLocked(actionType DeltaType, obj interface{}) error {
	id, err := f.KeyOf(obj)
	if err != nil {
		return KeyError{obj, err}
	}
	oldDeltas := f.items[id] // 根据 key 获取旧的 deltas 列表
	newDeltas := append(oldDeltas, Delta{actionType, obj}) // 往 deltas 里面推新获取的对象
	newDeltas = dedupDeltas(newDeltas) // 去除最新重复的对象

	if len(newDeltas) > 0 {
		if _, exists := f.items[id]; !exists { // 如果对象没在 deltas 出现过，则往队列推
			f.queue = append(f.queue, id)
		}
		f.items[id] = newDeltas
		f.cond.Broadcast() // 通知 pop()
	} else {
		f.items[id] = newDeltas
		return fmt.Errorf("Impossible dedupDeltas for id=%q: oldDeltas=%#+v, obj=%#+v; broke DeltaFIFO invariant by storing empty Deltas", id, oldDeltas, obj)
	}
	return nil
}
```

Pop() 是一个无限循环，一直等待队列中的入队对象，这里用了 `sync.Cond`，用来保证对象入队后，及时唤醒 Pop。当获取到值后，则先删除 items 里面的 deltas 列表，并调用 `process` 处理对象。当处理失败后，对象会再次入队。
```go
func (f *DeltaFIFO) Pop(process PopProcessFunc) (interface{}, error) {
	f.lock.Lock()
	defer f.lock.Unlock()
	for {
		for len(f.queue) == 0 {
			// When the queue is empty, invocation of Pop() is blocked until new item is enqueued.
			// When Close() is called, the f.closed is set and the condition is broadcasted.
			// Which causes this loop to continue and return from the Pop().
			if f.closed {
				return nil, ErrFIFOClosed
			}

			f.cond.Wait()
		}
		id := f.queue[0]
		f.queue = f.queue[1:]
		if f.initialPopulationCount > 0 {
			f.initialPopulationCount--
		}
		item, ok := f.items[id]
		if !ok {
			// This should never happen
			klog.Errorf("Inconceivable! %q was in f.queue but not f.items; ignoring.", id)
			continue
		}
		delete(f.items, id)
		err := process(item)
		if e, ok := err.(ErrRequeue); ok {
			f.addIfNotPresent(id, item)
			err = e.Err
		}
		// Don't need to copyDeltas here, because we're transferring
		// ownership to the caller.
		return item, err
	}
}
```

### HandleDeltas
`HandleDeltas` 用来处理 DeltasFIFO Pop 出来的对象，Pop 中调用的 process 则是这里配置的 `HandleDeltas` 方法。主体逻辑是遍历 Deltas，根据不同的类型，往 `indexer` 中添加、更新、删除数据。同时，也通过 `sharedProcessor` 向 `Listener` 通知事件。
```go
func (s *sharedIndexInformer) HandleDeltas(obj interface{}) error {
	s.blockDeltas.Lock()
	defer s.blockDeltas.Unlock()

	// from oldest to newest
	for _, d := range obj.(Deltas) {
		switch d.Type {
		case Sync, Replaced, Added, Updated:
			s.cacheMutationDetector.AddObject(d.Object)
			if old, exists, err := s.indexer.Get(d.Object); err == nil && exists {
				if err := s.indexer.Update(d.Object); err != nil {
					return err
				}

				isSync := false
				switch {
				case d.Type == Sync:
					// Sync events are only propagated to listeners that requested resync
					isSync = true
				case d.Type == Replaced:
					if accessor, err := meta.Accessor(d.Object); err == nil {
						if oldAccessor, err := meta.Accessor(old); err == nil {
							// Replaced events that didn't change resourceVersion are treated as resync events
							// and only propagated to listeners that requested resync
							isSync = accessor.GetResourceVersion() == oldAccessor.GetResourceVersion()
						}
					}
				}
				s.processor.distribute(updateNotification{oldObj: old, newObj: d.Object}, isSync)
			} else {
				if err := s.indexer.Add(d.Object); err != nil {
					return err
				}
				s.processor.distribute(addNotification{newObj: d.Object}, false)
			}
		case Deleted:
			if err := s.indexer.Delete(d.Object); err != nil {
				return err
			}
			s.processor.distribute(deleteNotification{oldObj: d.Object}, false)
		}
	}
	return nil
}
```

### sharedProcessor
`sharedProcessor` 负责启动已注册的 `listener`，并启动 `listener` 的 pop 循环。
```go
func (p *sharedProcessor) run(stopCh <-chan struct{}) {
	func() {
		p.listenersLock.RLock()
		defer p.listenersLock.RUnlock()
		for _, listener := range p.listeners {
			p.wg.Start(listener.run)
			p.wg.Start(listener.pop)
		}
		p.listenersStarted = true
	}()
	<-stopCh
	p.listenersLock.RLock()
	defer p.listenersLock.RUnlock()
	for _, listener := range p.listeners {
		close(listener.addCh) // Tell .pop() to stop. .pop() will tell .run() to stop
	}
	p.wg.Wait() // Wait for all .pop() and .run() to stop
}
```

### processorListener
`processorListener` 提供 add 和 pop 方法，上文说的的 `handleDelta` 会调用 add 方法来通知事件。然后 pop 接受到事件，通过 nextCh 通道完成事件的回调。
```go
func (p *processorListener) add(notification interface{}) {
	p.addCh <- notification
}

func (p *processorListener) pop() {
	defer utilruntime.HandleCrash()
	defer close(p.nextCh) // Tell .run() to stop

	var nextCh chan<- interface{}
	var notification interface{}
	for {
		select {
		case nextCh <- notification:
			// Notification dispatched
			var ok bool
			notification, ok = p.pendingNotifications.ReadOne()
			if !ok { // Nothing to pop
				nextCh = nil // Disable this select case
			}
		case notificationToAdd, ok := <-p.addCh:
			if !ok {
				return
			}
			if notification == nil { // No notification to pop (and pendingNotifications is empty)
				// Optimize the case - skip adding to pendingNotifications
				notification = notificationToAdd
				nextCh = p.nextCh
			} else { // There is already a notification waiting to be dispatched
				p.pendingNotifications.WriteOne(notificationToAdd)
			}
		}
	}
}

func (p *processorListener) run() {
	// this call blocks until the channel is closed.  When a panic happens during the notification
	// we will catch it, **the offending item will be skipped!**, and after a short delay (one second)
	// the next notification will be attempted.  This is usually better than the alternative of never
	// delivering again.
	stopCh := make(chan struct{})
	wait.Until(func() {
		for next := range p.nextCh {
			switch notification := next.(type) {
			case updateNotification:
				p.handler.OnUpdate(notification.oldObj, notification.newObj)
			case addNotification:
				p.handler.OnAdd(notification.newObj)
			case deleteNotification:
				p.handler.OnDelete(notification.oldObj)
			default:
				utilruntime.HandleError(fmt.Errorf("unrecognized notification: %T", next))
			}
		}
		// the only way to get here is if the p.nextCh is empty and closed
		close(stopCh)
	}, 1*time.Second, stopCh)
}
```

### 启动 Controller
controller 启动有两个重要的地方，一个是创建 Reflector 并运行，一个是 `processLoop` 处理循环。Reflector 中的 Queue 参数则是 `DeltaFIFO`，也是上一步创建好的，接下来的 Reflector 组件会把从 List/Watch 中获取到的对象，加入到 Queue 中。
```go
func (c *controller) Run(stopCh <-chan struct{}) {
	defer utilruntime.HandleCrash()
	go func() {
		<-stopCh
		c.config.Queue.Close()
	}()
	r := NewReflector(
		c.config.ListerWatcher,
		c.config.ObjectType,
		c.config.Queue,
		c.config.FullResyncPeriod,
	)
	r.ShouldResync = c.config.ShouldResync
	r.WatchListPageSize = c.config.WatchListPageSize
	r.clock = c.clock
	if c.config.WatchErrorHandler != nil {
		r.watchErrorHandler = c.config.WatchErrorHandler
	}

	c.reflectorMutex.Lock()
	c.reflector = r
	c.reflectorMutex.Unlock()

	var wg wait.Group

	wg.StartWithChannel(stopCh, r.Run)

	wait.Until(c.processLoop, time.Second, stopCh)
	wg.Wait()
}
```

## 开启 Reflector 监听
启动 Reflector 的函数中，用了 BackoffUntil 来确保 `ListAndWatch` 正确执行了。
```go
func (r *Reflector) Run(stopCh <-chan struct{}) {
	klog.V(3).Infof("Starting reflector %s (%s) from %s", r.expectedTypeName, r.resyncPeriod, r.name)
	wait.BackoffUntil(func() {
		if err := r.ListAndWatch(stopCh); err != nil {
			r.watchErrorHandler(r, err)
		}
	}, r.backoffManager, true, stopCh)
	klog.V(3).Infof("Stopping reflector %s (%s) from %s", r.expectedTypeName, r.resyncPeriod, r.name)
}
```
`ListAndWatch` 的函数非常地长，主要是两部分，List 和 Watch。
```go
		// 截取的部分 list 代码
		pager := pager.New(pager.SimplePageFunc(func(opts metav1.ListOptions) (runtime.Object, error) {
						return r.listerWatcher.List(opts)
					}))
		// 调用 API-Server 获取资源列表
		list, paginatedResult, err = pager.List(context.Background(), options)

        // list 成功
		r.setIsLastSyncResourceVersionUnavailable(false) // list was successful
		initTrace.Step("Objects listed")
		listMetaInterface, err := meta.ListAccessor(list)
		if err != nil {
			return fmt.Errorf("unable to understand list result %#v: %v", list, err)
		}
		resourceVersion = listMetaInterface.GetResourceVersion()
		initTrace.Step("Resource version extracted")
		items, err := meta.ExtractList(list)
		if err != nil {
			return fmt.Errorf("unable to understand list result %#v (%v)", list, err)
		}
		initTrace.Step("Objects extracted")
		// 往 DeltaFIFO 更新数据
		if err := r.syncWith(items, resourceVersion); err != nil {
			return fmt.Errorf("unable to sync list result: %v", err)
		}
		// sync 完成
		initTrace.Step("SyncWith done")
		r.setLastSyncResourceVersion(resourceVersion)
		initTrace.Step("Resource version updated")
```
`List` 通过调用 k8s api，获取资源列表，然后往 DeltaFIFO 更新数据。
接下来，看一下 `Watch` 部分。

```go
// Watch 长链接接口
w, err := r.listerWatcher.Watch(options)
// Watch 处理器
r.watchHandler(start, w, &resourceVersion, resyncerrc, stopCh)
```
```go
func (r *Reflector) watchHandler(start time.Time, w watch.Interface, resourceVersion *string, errc chan error, stopCh <-chan struct{}) error {
	eventCount := 0

	// Stopping the watcher should be idempotent and if we return from this function there's no way
	// we're coming back in with the same watch interface.
	defer w.Stop()

loop:
	for {
		select {
		case <-stopCh:
			return errorStopRequested
		case err := <-errc:
			return err
		case event, ok := <-w.ResultChan():
			if !ok {
				break loop
			}
			if event.Type == watch.Error {
				return apierrors.FromObject(event.Object)
			}
			if r.expectedType != nil {
				if e, a := r.expectedType, reflect.TypeOf(event.Object); e != a {
					utilruntime.HandleError(fmt.Errorf("%s: expected type %v, but watch event object had type %v", r.name, e, a))
					continue
				}
			}
			if r.expectedGVK != nil {
				if e, a := *r.expectedGVK, event.Object.GetObjectKind().GroupVersionKind(); e != a {
					utilruntime.HandleError(fmt.Errorf("%s: expected gvk %v, but watch event object had gvk %v", r.name, e, a))
					continue
				}
			}
			meta, err := meta.Accessor(event.Object)
			if err != nil {
				utilruntime.HandleError(fmt.Errorf("%s: unable to understand watch event %#v", r.name, event))
				continue
			}
			newResourceVersion := meta.GetResourceVersion()
			switch event.Type {
			case watch.Added:
				err := r.store.Add(event.Object)
				if err != nil {
					utilruntime.HandleError(fmt.Errorf("%s: unable to add watch event object (%#v) to store: %v", r.name, event.Object, err))
				}
			case watch.Modified:
				err := r.store.Update(event.Object)
				if err != nil {
					utilruntime.HandleError(fmt.Errorf("%s: unable to update watch event object (%#v) to store: %v", r.name, event.Object, err))
				}
			case watch.Deleted:
				// TODO: Will any consumers need access to the "last known
				// state", which is passed in event.Object? If so, may need
				// to change this.
				err := r.store.Delete(event.Object)
				if err != nil {
					utilruntime.HandleError(fmt.Errorf("%s: unable to delete watch event object (%#v) from store: %v", r.name, event.Object, err))
				}
			case watch.Bookmark:
				// A `Bookmark` means watch has synced here, just update the resourceVersion
			default:
				utilruntime.HandleError(fmt.Errorf("%s: unable to understand watch event %#v", r.name, event))
			}
			*resourceVersion = newResourceVersion
			r.setLastSyncResourceVersion(newResourceVersion)
			if rvu, ok := r.store.(ResourceVersionUpdater); ok {
				rvu.UpdateResourceVersion(newResourceVersion)
			}
			eventCount++
		}
	}

	watchDuration := r.clock.Since(start)
	if watchDuration < 1*time.Second && eventCount == 0 {
		return fmt.Errorf("very short watch: %s: Unexpected watch close - watch lasted less than a second and no items received", r.name)
	}
	klog.V(4).Infof("%s: Watch close - %v total %v items received", r.name, r.expectedTypeName, eventCount)
	return nil
}
```
在 `watchHandler` 中，会不停地从 Watch 接口中获取数据，一旦获取到数据，就根据 Watch 到的类型，分别往 `DeltaFIFO` 中执行对应的操作，添加、删除、更新之类的。

## processLoop
controller 最终执行到 `processLoop`，`processLoop` 是一个无限循环，不停从 `DeltaFIFO` 中 `Pop` 数据，并调用之前 controller 配置的 process 方法 `HandleDeltas` 来处理出队的数据。如果执行失败则调用 `AddIfNotPresent` 重新入队。
```go
func (c *controller) processLoop() {
	for {
		obj, err := c.config.Queue.Pop(PopProcessFunc(c.config.Process))
		if err != nil {
			if err == ErrFIFOClosed {
				return
			}
			if c.config.RetryOnError {
				// This is the safe way to re-enqueue.
				c.config.Queue.AddIfNotPresent(obj)
			}
		}
	}
}
```

# 总结
Informer 是 k8s 中非常重要的一部分，所有 controller 和 API-Server 交互都是用这个框架来做的。上面的源码分析，能让我们了解到 Informer 的执行原理，知道了数据的整体流转。在整个 Informer 框架中，用了两种存储结构，DeltaFIFO 和 ThreadSafeStore，这里面用到了大量的应对并发的方式。DeltaFIFO 的设计保证了队列数据的顺序性和唯一性，ThreadSafeStore 的设计则保证了缓存的并发安全性。ThreadSafeStore 的索引设计虽然比较绕，但是能适应多种索引方式。

# Reference
- https://www.luozhiyun.com/archives/391
- https://github.com/kubernetes/sample-controller/blob/master/docs/controller-client-go.md
- https://itnext.io/how-to-create-a-kubernetes-custom-controller-using-client-go-f36a7a7536cc

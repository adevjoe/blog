build:
	hugo

deploy: build
	scp -r ./public/* joe@mango:/home/joe/web/blog
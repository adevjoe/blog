all: image

image:
		@python3 up

run:
		hugo serve

dep:
		@python3 -m pip install -r Requirements.txt
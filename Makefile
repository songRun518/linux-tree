dev:
	zig build

release:
	zig build -Doptimize=ReleaseFast

all: release dev

.PHONY: dev release all

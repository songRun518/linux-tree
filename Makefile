CMD = zig build

dev:
	$(CMD) --prefix-exe-dir zig-out/dev \

release:
	$(CMD) --prefix-exe-dir zig-out/release \
	-Doptimize=ReleaseFast -Dcpu=native \

all: release dev

.PHONY: dev release all
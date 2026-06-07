CMD = zig build -fincremental

dev:
	$(CMD) -p . --prefix-exe-dir zig-out/dev \

release:
	$(CMD) -p . --prefix-exe-dir zig-out/release \
	-Doptimize=ReleaseSafe -Dcpu=native \

.PHONY: dev release
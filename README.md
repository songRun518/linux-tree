# linux-tree

A fast, lightweight directory tree viewer written in Zig.

## Features

- **Low memory footprint** — Optimized for minimal resource usage
- **Fast performance** — Benchmarked faster than comparable tools

## Installation

### Build from source

Requires [Zig](https://ziglang.org/) compiler.

```bash
make release
```

The binary will be available at `zig-out/bin/tree`.

## Usage

```bash
tree [options] [directories ...]
```

### Options

| Flag | Description |
|------|-------------|
| `-h`, `--help` | Show help message and exit |
| `-s` | Show each item's size |
| `-a` | List all files (including hidden) |
| `-L <level>` | Limit recursion depth |
| `--no-color` | Disable colored output |

### Examples

```bash
# Show current directory tree
tree

# Show tree with file sizes
tree -s

# Limit depth to 2 levels
tree -L 2

# Include hidden files
tree -a

# Multiple directories
tree /home /etc
```
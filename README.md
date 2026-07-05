# linux-tree

A fast, lightweight directory tree viewer written in Zig.

## Features

- **Tree visualization** — Display directory contents in a classic tree format
- **Color-coded output** — Different colors for directories, executables, symlinks, devices, and more
- **Symlink detection** — Shows symlink targets and highlights broken links
- **File size display** — Optional human-readable size output (B/K/M/G)
- **Depth limiting** — Control how deep the tree descends
- **Hidden file support** — Toggle hidden files with a simple flag
- **Low memory footprint** — Optimized for minimal resource usage
- **Fast performance** — Benchmarked faster than comparable tools

## Installation

### Build from source

Requires [Zig](https://ziglang.org/) compiler.

```bash
zig build -Doptimize=ReleaseFast
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

## Output Colors

| Color | File Type |
|-------|-----------|
| Blue (bold) | Directories |
| Green (bold) | Executable files |
| Cyan | Symbolic links |
| Red | Broken symbolic links |
| Yellow | Block/character devices, named pipes |
| Magenta | Media files, archives, Unix domain sockets |
| Yellow (bold) | Error messages |

## Performance

Benchmarked against `eza -T` on the `~` directory:

- **Memory usage**: Significantly lower than `eza -T`
- **Speed**: Slightly faster than `eza -T`

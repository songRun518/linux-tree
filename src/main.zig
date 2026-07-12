const std = @import("std");
const Allocator = std.mem.Allocator;
const Io = std.Io;
const Dir = Io.Dir;
const File = Io.File;
const path = Dir.path;

const cli = @import("cli.zig");
const color = @import("color.zig");
const detail = @import("detail.zig");
const DirIter = @import("DirIter.zig");
const fatal_fn = @import("fatal_fn.zig");
const stdout = @import("stdout.zig");

pub const control = struct {
    pub var list_all = false;
    pub var max_level: ?u16 = null;
    pub var no_color: bool = false;
    pub var show_size: bool = false;
};

var stdout_buffer: [8 * 1024]u8 = undefined;

pub fn main(init: std.process.Init) !u8 {
    const gpa = init.gpa;
    const io = init.io;

    stdout.init(io, init.environ_map);
    defer stdout.flush();

    const dir_paths = cli.handleCli(
        gpa,
        init.minimal.args,
    ) catch |err| switch (err) {
        cli.Error.ExitSuccess => return 0,
        cli.Error.ExitFailure => return 1,
        cli.Error.OutOfMemory => fatal_fn.outOfMemery(),
    };
    defer gpa.free(dir_paths);
    if (!stdout.is_style_supported) control.no_color = true;

    for (dir_paths) |dir_path| {
        const dir = Dir.cwd().openDir(
            io,
            dir_path,
            .{ .iterate = true },
        ) catch |err| {
            std.log.err("{t} @ open dir '{s}'", .{ err, dir_path });
            return 1;
        };
        defer dir.close(io);

        stdout.print("{s}{s}{s}\n", .{ color.getSimple(.directory), dir_path, color.getReset() });

        try makeTree(gpa, io, dir, 1);
    }

    return 0;
}

var prev_branch_buffer: [Dir.max_path_bytes]u21 = undefined;

fn makeTree(
    gpa: Allocator,
    io: Io,
    dir_or_err: Dir.OpenError!Dir,
    level: usize,
) !void {
    const dir = dir_or_err catch |err| {
        printLastError(err, level);
        return;
    };
    var it = DirIter.init(io, dir);
    while (true) {
        const entry = it.next() catch |err| {
            printLastError(err, level);
            return;
        } orelse break;

        const is_last = null == try it.peek();

        for (0..level - 1) |i| {
            // Prints one branch and three space.
            stdout.print("{u}   ", .{prev_branch_buffer[i]});
        }
        // Prints four width.
        stdout.print("{u}── ", .{@as(u21, if (is_last) '└' else '├')});
        // Prints details by file kind.
        printDetail(io, dir, entry);

        const is_in_range = if (control.max_level) |ml| level < ml else true;
        if (is_in_range and entry.kind == .directory) {
            const next = dir.openDir(
                io,
                entry.name,
                .{ .iterate = true, .follow_symlinks = false },
            );
            defer if (next) |nd| nd.close(io) else |_| {};

            prev_branch_buffer[level - 1] = if (is_last) ' ' else '│';

            try makeTree(
                gpa,
                io,
                next,
                level + 1,
            );
        }
    }
}

fn printLastError(err: anyerror, level: usize) void {
    for (0..level - 1) |i| {
        // Prints one branch and three space.
        stdout.print("{u}   ", .{prev_branch_buffer[i]});
    }
    // Prints four width.
    stdout.print("{u}── ", .{@as(u21, '└')});
    stdout.print(" {s}error:{s} {t}\n", .{ color.getError(), color.getReset(), err });
}

fn printDetail(io: Io, dir: Dir, entry: Dir.Entry) void {
    detail.update(io, dir, entry);
    if (control.show_size) stdout.print("[{s}] ", .{byteToHuman(detail.size())});
    if (entry.kind == .sym_link) {
        stdout.print("{s}{s}{s} -> ", .{
            color.getSimple(.sym_link),
            entry.name,
            color.getReset(),
        });
        if (detail.target_path.?) |p| {
            if (Dir.path.dirname(p)) |prefix| {
                stdout.print("{s}{s}/{s}", .{ color.getTargetPrefix(), prefix, color.getReset() });
            }
            const basename = Dir.path.basename(p);
            stdout.print("{s}{s}{s}\n", .{
                color.getTarget(),
                basename,
                color.getReset(),
            });
        } else |err| {
            stdout.print("{s}error:{s} {t}", .{ color.getError(), color.getReset(), err });
        }
    } else {
        stdout.print("{s}{s}{s}\n", .{
            color.get(entry),
            entry.name,
            color.getReset(),
        });
    }
}

var str_buf: [20]u8 = undefined;
fn byteToHuman(b_in_int: u64) []const u8 {
    const b: f64 = @floatFromInt(b_in_int);
    const kb = b / 1024;
    const mb = kb / 1024;
    const gb = mb / 1024;

    var size_unit: []const u8 = "";
    var value: f64 = 0;

    if (gb >= 1) {
        size_unit = "G";
        value = gb;
    } else if (mb >= 1) {
        size_unit = "M";
        value = mb;
    } else if (kb >= 1) {
        size_unit = "K";
        value = kb;
    } else {
        size_unit = "B";
        value = b;
    }

    return std.fmt.bufPrint(&str_buf, "{d:.1} {s}", .{ value, size_unit }) catch {
        @branchHint(.cold);
        unreachable;
    };
}

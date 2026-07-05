const std = @import("std");
const Allocator = std.mem.Allocator;
const Io = std.Io;
const Dir = Io.Dir;
const File = Io.File;
const path = Dir.path;

const cli = @import("cli.zig");
const detail = @import("detail.zig");
const DirIter = @import("DirIter.zig");
const fatal_fn = @import("fatal_fn.zig");
const output = @import("output.zig");

pub const control = struct {
    pub var list_all = false;
    pub var max_level: ?u16 = null;
    pub var no_color: bool = true;
    pub var show_size: bool = false;
};

var stdout_buffer: [8 * 1024]u8 = undefined;

pub fn main(init: std.process.Init) !u8 {
    const gpa = init.gpa;
    const io = init.io;

    output.init(io);
    defer output.deinit();

    const dir_paths = cli.handleCli(
        gpa,
        init.minimal.args,
    ) catch |err| switch (err) {
        cli.Error.ExitSuccess => return 0,
        cli.Error.ExitFailure => return 1,
        cli.Error.OutOfMemory => fatal_fn.outOfMemery(),
    };
    defer gpa.free(dir_paths);

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

        output.print("{s}\n", .{dir_path});

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
            output.print("{u}   ", .{prev_branch_buffer[i]});
        }
        // Prints four width.
        output.print("{u}── ", .{@as(u21, if (is_last) '└' else '├')});
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
        output.print("{u}   ", .{prev_branch_buffer[i]});
    }
    // Prints four width.
    output.print("{u}── ", .{@as(u21, '└')});
    output.print("error: {t}\n", .{err});
}

fn printDetail(io: Io, dir: Dir, entry: Dir.Entry) void {
    detail.update(io, dir, entry);
    if (control.show_size) output.print("[{d}] ", .{detail.size});
    if (entry.kind == .sym_link) {
        output.print("{s} -> ", .{entry.name});
        if (detail.target) |te| {
            if (te) |t| {
                output.print("{s}\n", .{t.path});
            } else |err| {
                output.print("error: {t}", .{err});
            }
        }
    } else {
        output.print("{s}\n", .{entry.name});
    }
}

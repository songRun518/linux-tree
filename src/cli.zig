const std = @import("std");
const Allocator = std.mem.Allocator;
const eql = std.mem.eql;
const startsWith = std.mem.startsWith;
const Io = std.Io;
const ArgIter = std.process.Args.Iterator;

const control = @import("main.zig").control;
const stdout = @import("stdout.zig");

pub const Error = error{
    ExitSuccess,
    ExitFailure,
} || Allocator.Error;

const help_message =
    \\Usage: tree [options] [dirs ...]
    \\
    \\General Options:
    \\  -h, --help          Print this help and exit
    \\
    \\Listing Options:
    \\  -s                  Show each item's size
    \\  -a                  All files are listed
    \\  -L [level]          Descend only level directories deep
    \\
    \\Output Options:
    \\  --no-color          Disable colored output.
;

pub fn handleCli(gpa: Allocator, args: std.process.Args) Error![]const [:0]const u8 {
    var dir_paths: std.ArrayList([:0]const u8) = .empty;
    errdefer dir_paths.deinit(gpa);

    var it = args.iterate();
    _ = it.skip();
    while (it.next()) |arg| {
        if (startsWith(u8, arg, "--")) {
            try handleLongArg(arg[2..]);
        } else if (startsWith(u8, arg, "-")) {
            try handleShortArg(arg[1..], &it);
        } else {
            try dir_paths.append(gpa, arg);
        }
    }

    if (dir_paths.items.len == 0) {
        try dir_paths.append(gpa, ".");
    }
    return try dir_paths.toOwnedSlice(gpa);
}

/// The `s` does not contain "--".
fn handleLongArg(s: []const u8) Error!void {
    if (eql(u8, s, "help")) {
        stdout.print("{s}\n", .{help_message});
        return Error.ExitSuccess;
    } else if (eql(u8, s, "no-color")) {
        control.no_color = true;
    } else {
        std.log.err("Unknown option: {s}", .{s});
        return Error.ExitFailure;
    }
}

/// The `s` does not contain "-".
fn handleShortArg(s: []const u8, it: *ArgIter) !void {
    for (s, 0..) |arg, index| {
        switch (arg) {
            'h' => {
                stdout.print("{s}\n", .{help_message});
                return Error.ExitSuccess;
            },
            's' => control.show_size = true,
            'a' => control.list_all = true,
            'L' => {
                const lvl_str, const is_done = if (index < s.len - 1)
                    .{ s[index + 1 ..], true }
                else
                    .{ it.next() orelse {
                        std.log.err("Missing value of '{c}'", .{arg});
                        return Error.ExitFailure;
                    }, false };
                control.max_level = std.fmt.parseInt(
                    u16,
                    lvl_str,
                    10,
                ) catch |err| {
                    std.log.err("{t} @ parse level of '{s}'", .{ err, lvl_str });
                    return Error.ExitFailure;
                };
                if (is_done) break;
            },
            else => {
                std.log.err("Unknown option: {c}", .{arg});
                return Error.ExitFailure;
            },
        }
    }
}

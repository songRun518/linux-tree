const std = @import("std");
const Allocator = std.mem.Allocator;
const eql = std.mem.eql;
const startsWith = std.mem.startsWith;
const Io = std.Io;

const root = @import("main.zig");
const filter = root.filter;

pub const Error = error{
    ExitHelp,
    MissingValue,
    UnknownOption,
};

pub const help_msg =
    \\Usage: tree [options] [dirs ...]
    \\
    \\General Options:
    \\  -h, --help          Print this help and exit
    \\
    \\Listing Options:
    \\  -a                  All files are listed
    \\  -L [level]          Descend only level directories deep
    \\
    \\Output Options:
    \\  --no-color          Disable colored output.
;

pub fn handleCli(gpa: Allocator, args: std.process.Args) ![]const []const u8 {
    var dirs: std.ArrayList([]const u8) = .empty;
    errdefer dirs.deinit(gpa);

    var it = args.iterate();
    _ = it.skip();
    while (it.next()) |arg| {
        if (startsWith(u8, arg, "--")) {
            try handleLongArg(arg[2..]);
        } else if (startsWith(u8, arg, "-")) {
            try handleShortArg(arg[1..], &it);
        } else {
            try dirs.append(gpa, arg);
        }
    }

    if (dirs.items.len == 0) {
        try dirs.append(gpa, ".");
    }
    return try dirs.toOwnedSlice(gpa);
}

/// The `s` does not contain "--".
fn handleLongArg(s: []const u8) !void {
    if (eql(u8, s, "help")) {
        return Error.ExitHelp;
    } else if (eql(u8, s, "no-color")) {
        filter.no_color = true;
    } else {
        std.log.err("unknown option: {s}", .{s});
        return Error.UnknownOption;
    }
}

/// The `s` does not contain "-".
fn handleShortArg(s: []const u8, it: *std.process.Args.Iterator) !void {
    var finished = false;
    for (s, 0..) |arg, index| {
        switch (arg) {
            'h' => return Error.ExitHelp,
            'a' => filter.list_all = true,
            'L' => {
                const val = if (index < s.len - 1) val: {
                    finished = true;
                    break :val s[index + 1 ..];
                } else it.next() orelse {
                    std.log.err("missing value of '{c}'", .{arg});
                    return Error.MissingValue;
                };
                filter.level = try std.fmt.parseInt(u16, val, 10);
            },
            else => {
                std.log.err("unknown option: {c}", .{arg});
                return Error.UnknownOption;
            },
        }
        if (finished) break;
    }
}

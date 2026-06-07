const std = @import("std");
const Allocator = std.mem.Allocator;
const eql = std.mem.eql;
const startsWith = std.mem.startsWith;
const Io = std.Io;
const root = @import("root");
const filter = root.filter;

pub const Error = error{
    Exit,
    MissingValue,
    UnknownOption,
};

const help_msg =
    \\Usage: tree [options] [dirs ...]
    \\
    \\General Options:
    \\  -h, --help          Print this help and exit
    \\
    \\Listing Options:
    \\  -a              All files are listed
    \\  -L [level]      Descend only level directories deep
;

pub fn perform(gpa: Allocator, args: std.process.Args, w: *Io.Writer) ![]const []const u8 {
    var dirs: std.ArrayList([]const u8) = .empty;
    errdefer dirs.deinit(gpa);

    var it = args.iterate();
    _ = it.skip();
    while (it.next()) |arg| {
        if (startsWith(u8, arg, "--")) {
            try long(arg[2..], w);
        } else if (startsWith(u8, arg, "-")) {
            try short(arg[1..], &it);
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
pub fn long(s: []const u8, w: *Io.Writer) !void {
    if (eql(u8, s, "help")) {
        try w.print("{s}\n", .{help_msg});
        return Error.Exit;
    } else {
        std.log.err("unknown option: {s}", .{s});
        return Error.UnknownOption;
    }
}

/// The `s` does not contain "-".
pub fn short(s: []const u8, it: *std.process.Args.Iterator) !void {
    var finished = false;
    for (s, 0..) |arg, index| {
        switch (arg) {
            'h' => return Error.Exit,
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

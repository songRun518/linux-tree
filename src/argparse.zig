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

const version: []const u8 = @import("bzz").version;
const help =
    \\Usage: tree [options] [dirs ...]
    \\
    \\General Options:
    \\  --version       Print version and exit 
    \\  --help          Print this help and exit 
    \\
    \\Listing Options:
    \\  -a              All files are listed
    \\  -L [level]      Descend only level directories deep
;

pub fn x(allocator: Allocator, args: std.process.Args, w: *Io.Writer) ![]const []const u8 {
    var dirs: std.ArrayList([]const u8) = .empty;
    errdefer dirs.deinit(allocator);

    var it = args.iterate();
    _ = it.skip();
    while (it.next()) |arg| {
        if (startsWith(u8, arg, "--")) {
            try long(arg[2..], w);
        } else if (startsWith(u8, arg, "-")) {
            try short(arg[1..], &it);
        } else {
            try dirs.append(allocator, arg);
        }
    }

    if (dirs.items.len == 0) {
        try dirs.append(allocator, ".");
    }
    return try dirs.toOwnedSlice(allocator);
}

/// The `argp` doesn't contain "--".
pub fn long(argp: []const u8, w: *Io.Writer) !void {
    if (eql(u8, argp, "help")) {
        try w.print("{s}\n", .{help});
        return Error.Exit;
    } else if (eql(u8, argp, "version")) {
        try w.print("{s}\n", .{version});
        return Error.Exit;
    }
}

/// The `argp` doesn't contain "-".
pub fn short(argp: []const u8, it: *std.process.Args.Iterator) !void {
    var finished = false;
    for (argp, 0..) |arg, index| {
        switch (arg) {
            'a' => filter.list_all = true,
            'L' => {
                const val = if (index < argp.len - 1) val: {
                    finished = true;
                    break :val argp[index + 1 ..];
                } else it.next() orelse return Error.MissingValue;
                filter.level = try std.fmt.parseInt(u16, val, 10);
            },
            else => return Error.UnknownOption,
        }
        if (finished) break;
    }
}

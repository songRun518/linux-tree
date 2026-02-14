const std = @import("std");
const Allocator = std.mem.Allocator;
const Io = std.Io;
const eql = std.mem.eql;
const startsWith = std.mem.startsWith;
const findScalarPos = std.mem.findScalarPos;
const ArgsIterator = std.process.Args.Iterator;

const Self = @This();

dir_paths: []const []const u8 = undefined,
list_all: bool = false,
level: ?u64 = null,

pub const Error = error{
    Exit,
    MissingValue,
    UnknownOption,
};

const version = "0.1.0";
const help =
    \\Usage: tree [options] [--] [dirs ...]
    \\
    \\General Options:
    \\  --version       Print version and exit 
    \\  --help          Print this help and exit 
    \\  --              Options processing terminator
    \\
    \\Listing Options:
    \\  -a              All files are listed
    \\  -L [level]      Descend only level directories deep
;

pub fn deinit(self: Self, arena: Allocator) void {
    arena.free(self.dir_paths);
}

pub fn parse(arena: Allocator, args: std.process.Args) !Self {
    var self: Self = .{};
    var dir_paths: std.ArrayList([]const u8) = .empty;
    errdefer dir_paths.deinit(arena);

    var it = args.iterate();
    defer it.deinit();
    _ = it.skip();

    var all_positional = false;
    while (it.next()) |arg| {
        if (all_positional) {
            try dir_paths.append(arena, arg);
            continue;
        }

        if (eql(u8, arg, "--")) {
            all_positional = true;
        } else if (startsWith(u8, arg, "--")) {
            try parseLong(arg[2..]);
        } else if (startsWith(u8, arg, "-")) {
            try parseShort(arg[1..], &it, &self);
        } else {
            try dir_paths.append(arena, arg);
        }
    }

    if (dir_paths.items.len == 0) try dir_paths.append(arena, ".");
    self.dir_paths = try dir_paths.toOwnedSlice(arena);
    return self;
}

/// `arg_pattern` does not contain "--".
fn parseLong(arg_pattern: []const u8) !void {
    const delimiter_pos = findScalarPos(u8, arg_pattern, 0, '=');
    const arg_name = if (delimiter_pos) |dp| arg_pattern[0..dp] else arg_pattern;
    if (eql(u8, arg_name, "version")) {
        std.log.info("{s}", .{version});
        return error.Exit;
    } else if (eql(u8, arg_name, "help")) {
        std.log.info("{s}", .{help});
        return error.Exit;
    } else {
        std.log.err("unknown option: {s}", .{arg_name});
        return error.UnknownOption;
    }
}

/// `arg_pattern` does not contain "-".
fn parseShort(arg_pattern: []const u8, it: *ArgsIterator, self: *Self) !void {
    var collected = false;
    for (arg_pattern, 0..) |arg, idx| {
        switch (arg) {
            'a' => self.list_all = true,
            'L' => {
                const val: []const u8 = if (idx == arg_pattern.len - 1) it.next() orelse {
                    std.log.err("missing a value: -L", .{});
                    return error.MissingValue;
                } else blk: {
                    collected = true;
                    break :blk arg_pattern[idx + 1 ..];
                };
                self.level = try std.fmt.parseInt(u64, val, 10);
            },
            else => {
                std.log.err("unknown option: -{c}", .{arg});
                return error.UnknownOption;
            },
        }
        if (collected) break;
    }
}

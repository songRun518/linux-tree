const std = @import("std");
const Allocator = std.mem.Allocator;
const Io = std.Io;
const File = Io.File;
const Dir = Io.Dir;
const Iterator = Dir.Iterator;
const Entry = Dir.Entry;

const control = @import("main.zig").control;

io: Io,
underlying: Iterator,
peeked: ?Entry,

pub fn init(io: Io, dir: Dir) @This() {
    return .{
        .io = io,
        .underlying = dir.iterate(),
        .peeked = null,
    };
}

pub fn next(self: *@This()) Iterator.Error!?Entry {
    if (self.peeked) |entry| {
        self.peeked = null;
        return entry;
    }
    while (true) {
        const entry = try self.underlying.next(self.io) orelse return null;
        if (entry.name[0] == '.' and !control.list_all) continue;
        return entry;
    }
}

pub fn peek(self: *@This()) Iterator.Error!?*const Entry {
    if (self.peeked) |entry| return &entry;
    self.peeked = try self.next() orelse return null;
    return &self.peeked.?;
}

const std = @import("std");
const fatal = std.process.fatal;

pub fn outOfMemery() noreturn {
    @branchHint(.cold);
    fatal("{t}", .{std.mem.Allocator.Error.OutOfMemory});
}

pub fn output(err: anyerror) noreturn {
    @branchHint(.cold);
    fatal("[{t}] Failed to output", .{err});
}

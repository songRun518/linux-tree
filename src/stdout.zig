const std = @import("std");
const Io = std.Io;
const File = Io.File;

const fatal = @import("fatal_fn.zig").output;

var stdout_buffer: [8 * 1024]u8 = undefined;
var fw: File.Writer = undefined;
var w: *Io.Writer = undefined;

pub fn init(io: Io) void {
    fw = File.stdout().writer(io, &stdout_buffer);
    w = &fw.interface;
}

pub fn deinit() void {
    fw.flush() catch |err| fatal(err);
}

pub fn print(comptime fmt: []const u8, args: anytype) void {
    w.print(fmt, args) catch |err| fatal(err);
}

pub fn writeAll(bytes: []const u8) void {
    w.writeAll(bytes) catch |err| fatal(err);
}

pub fn printAsciiChar(c: u8, options: std.fmt.Options) void {
    w.printAsciiChar(c, options) catch |err| fatal(err);
}

const std = @import("std");
const Io = std.Io;
const File = Io.File;
const eql = std.mem.eql;

const fatal = @import("fatal_fn.zig").output;

var stdout_buffer: [8 * 1024]u8 = undefined;
var fw: File.Writer = undefined;
var w: *Io.Writer = undefined;

pub var is_style_supported: bool = false;

pub fn init(io: Io, environ_map: *std.process.Environ.Map) void {
    fw = File.stdout().writer(io, &stdout_buffer);
    w = &fw.interface;

    const is_tty = File.stdout().isTty(io) catch {
        @branchHint(.cold);
        unreachable;
    };
    if (!is_tty) return;
    const colorterm = environ_map.get("COLORTERM") orelse return;
    is_style_supported = eql(u8, colorterm, "truecolor") or eql(u8, colorterm, "24bit");
}

pub fn flush() void {
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

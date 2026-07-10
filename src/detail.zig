const std = @import("std");
const Allocator = std.mem.Allocator;
const Io = std.Io;
const Dir = Io.Dir;
const File = Io.File;

const control = @import("main.zig").control;

/// Seen as the normal if it is null.
var origin_stat: ?File.Stat = null;
/// It is not a symlink if is is null.
///
/// Always exists if it is symlink.
pub var target_path: ?Dir.ReadLinkError![]const u8 = null;
/// It is not a symlink if is is null.
///
/// Always exists if it is symlink.
var target_stat: ?Dir.StatFileError!File.Stat = null;

var read_link_buffer: [Dir.max_path_bytes]u8 = undefined;

pub fn update(io: Io, dir: Dir, entry: Dir.Entry) void {
    setDefault();

    if (dir.statFile(
        io,
        entry.name,
        .{ .follow_symlinks = false },
    )) |o_s| {
        origin_stat = o_s;
    } else |_| {}

    if (entry.kind != .sym_link) return;
    target_path = rl: {
        const len = dir.readLink(
            io,
            entry.name,
            &read_link_buffer,
        ) catch |err| break :rl err;
        break :rl read_link_buffer[0..len];
    };
    target_stat = dir.statFile(
        io,
        entry.name,
        .{ .follow_symlinks = true },
    );
}

fn setDefault() void {
    origin_stat = null;
    target_path = null;
    target_stat = null;
}

const exe_mask_code = 0o111;

/// Returns zero if `origin_stat` is null.
pub fn size() u64 {
    return if (origin_stat) |o_s| o_s.size else 0;
}

/// Returns `.file` if `origin_stat` is null.
pub fn originKind() File.Kind {
    return if (origin_stat) |o_s|
        o_s.kind
    else
        .file;
}

/// Returns `.file` if `target_stat` is null or error.
pub fn targetKind() File.Kind {
    return if (target_stat) |t_s_e|
        if (t_s_e) |t_s|
            t_s.kind
        else |_|
            .file
    else
        .file;
}

/// Checks it is a file and executable.
///
/// Returns **false** if `origin_stat` is null.
pub fn isOriginExecutable() bool {
    return if (origin_stat) |o_s|
        o_s.kind == .file and (@intFromEnum(o_s.permissions) & exe_mask_code) != 0
    else
        false;
}

/// Checks it is a file and executable.
///
/// Returns **false** if `target_stat` is null or error.
pub fn isTargetExecutable() bool {
    return if (target_stat) |t_s_e|
        if (t_s_e) |t_s|
            t_s.kind == .file and (@intFromEnum(t_s.permissions) & exe_mask_code) != 0
        else |_|
            false
    else
        false;
}

/// Only when `error.FileNotFound` occurred does it return true.
pub fn isBadLink() bool {
    if (target_path == null) return false;
    return if (target_stat) |t_s| t_s: {
        break :t_s t_s == error.FileNotFound;
    } else false;
}

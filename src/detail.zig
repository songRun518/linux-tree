const std = @import("std");
const Allocator = std.mem.Allocator;
const Io = std.Io;
const Dir = Io.Dir;
const File = Io.File;

const control = @import("main.zig").control;

pub var size: u64 = 0;
/// Only analysed as it's file.
pub var is_executable: bool = false;
pub var is_bad_link: bool = false;
/// Exists if it isn't bad link.
pub var target: ?Dir.ReadLinkError!Target = null;

/// Symlink's target infomation.
pub const Target = struct {
    path: []const u8,
    /// Exists if stat successfully.
    kind: ?File.Kind,
    is_executable: bool,
};

pub fn update(io: Io, dir: Dir, entry: Dir.Entry) void {
    setDefault();
    const original_stat = if (control.show_size) statSize(io, dir, entry) else null;
    if (entry.kind == .file) updateExecutable(original_stat) //
    else if (entry.kind == .sym_link) updateSymLink(io, dir, entry);
}

fn setDefault() void {
    size = 0;
    is_executable = false;
    is_bad_link = false;
    target = null;
}

/// Returns stat not following the symlink.
fn statSize(io: Io, dir: Dir, entry: Dir.Entry) ?File.Stat {
    const stat = dir.statFile(
        io,
        entry.name,
        .{ .follow_symlinks = false },
    ) catch return null;
    size = stat.size;
    return stat;
}

const check_exe_mask = 0o111;

fn updateExecutable(__stat: ?File.Stat) void {
    if (control.no_color) return;

    const stat = __stat orelse return;
    const perm = @intFromEnum(stat.permissions);
    is_executable = (perm & check_exe_mask) != 0;
}

var read_link_buffer: [Dir.max_path_bytes]u8 = undefined;

fn updateSymLink(io: Io, dir: Dir, entry: Dir.Entry) void {
    const read_len = dir.readLink(io, entry.name, &read_link_buffer) catch |err| {
        target = err;
        return;
    };

    var __target = Target{
        .path = read_link_buffer[0..read_len],
        .kind = null,
        .is_executable = false,
    };
    defer target = __target;

    const target_stat = dir.statFile(
        io,
        entry.name,
        .{ .follow_symlinks = true },
    ) catch |err| {
        if (err == error.FileNotFound) is_bad_link = true;
        return;
    };
    __target.kind = target_stat.kind;
    const perm = @intFromEnum(target_stat.permissions);
    __target.is_executable = (perm & check_exe_mask) != 0;
}

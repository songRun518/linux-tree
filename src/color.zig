const std = @import("std");
const Allocator = std.mem.Allocator;
const Io = std.Io;
const Dir = Io.Dir;
const File = Io.File;
const eql = std.mem.eql;

const control = @import("main.zig").control;
const detail = @import("detail.zig");
const output = @import("output.zig");

pub const block_device_style = "\x1b[33m";
pub const character_device_style = "\x1b[33m";
pub const directory_style = "\x1b[1;34m";
pub const named_pipe_style = "\x1b[33m";
pub const unix_domain_socket_style = "\x1b[35m";
pub const door_style = "\x1b[35m";
pub const sym_link_style = "\x1b[36m";
pub const bad_link_style = "\x1b[31m";
pub const reset_style = "\x1b[0m";
pub const error_style = "\x1b[1;33m";

/// Assert `kind` is not file and sym_link.
fn getSimpleKind(kind: File.Kind) []const u8 {
    return if (control.no_color) reset_style else switch (kind) {
        .block_device => block_device_style,
        .character_device => character_device_style,
        .directory => directory_style,
        .named_pipe => named_pipe_style,
        .unix_domain_socket => unix_domain_socket_style,
        .door => door_style,
        else => reset_style, //.event_port .whiteout .unknown
        .sym_link, .file => unreachable,
    };
}

const media_style = "\x1b[1;35m";
const archive_style = "\x1b[1;35m";
const executable_style = "\x1b[1;32m";

const media_extensions = [_][]const u8{
    ".png", ".jpg", ".jpeg", ".gif", ".webp", ".svg", ".bmp", ".ico",  ".tiff",
    ".mp3", ".wav", ".flac", ".ogg", ".m4a",  ".aac", ".mid", ".wma",  ".mp4",
    ".mkv", ".mov", ".webm", ".avi", ".wmv",  ".flv", ".mpg", ".mpeg",
};
const archive_extensions = [_][]const u8{
    ".7z", ".xz", ".zip", ".tar", ".gz", ".bz2", ".rar", ".iso", ".lzma", ".cab",
};

fn getTreeFile(io: Io, dir: Dir, entry: Dir.Entry) []const u8 {
    if (control.no_color) return reset_style;

    const is_executale = check_exe: {
        const stat = dir.statFile(
            io,
            entry.name,
            .{ .follow_symlinks = false },
        ) catch break :check_exe false;
        const perm = @intFromEnum(stat.permissions);
        break :check_exe perm & 0o0111 != 0;
    };
    if (is_executale) return executable_style;

    const f_ext = Dir.path.extension(entry.name);
    for (media_extensions) |ext| {
        if (eql(u8, f_ext, ext)) return media_style;
    }
    for (archive_extensions) |ext| {
        if (eql(u8, f_ext, ext)) return archive_style;
    }

    return reset_style;
}

/// Returns null if it's bad link.
fn getTargetFile(io: Io, dir: Dir, entry: Dir.Entry) ?[]const u8 {
    if (control.no_color) return reset_style;

    const is_executale = check_exe: {
        const stat = dir.statFile(
            io,
            entry.name,
            .{ .follow_symlinks = true },
        ) catch |err| switch (err) {
            error.FileNotFound => return null, // bad link
            else => break :check_exe false,
        };
        const perm = @intFromEnum(stat.permissions);
        break :check_exe perm & 0o0111 != 0;
    };
    if (is_executale) return executable_style;

    const f_ext = Dir.path.extension(entry.name);
    for (media_extensions) |ext| {
        if (eql(u8, f_ext, ext)) return media_style;
    }
    for (archive_extensions) |ext| {
        if (eql(u8, f_ext, ext)) return archive_style;
    }

    return reset_style;
}

var read_link_buffer: [Dir.max_path_bytes]u8 = undefined;

pub fn printDetails(io: Io, dir: Dir, entry: Dir.Entry) void {
    if (entry.kind != .sym_link) {
        const style = switch (entry.kind) {
            .file => getTreeFile(io, dir, entry),
            .sym_link => unreachable,
            else => getSimpleKind(entry.kind),
        };
        output.print("{s}{s}{s}\n", .{ style, entry.name, reset_style });
        return;
    }

    const target = dir.readLink(io, entry.name, &read_link_buffer);
    if (target) |read_len| {
        const path = read_link_buffer[0..read_len];
        if (getTargetFile(io, dir, entry)) |style| {
            const prefix = Dir.path.dirname(path);
            const basename = Dir.path.basename(path);
            output.print("{s}{s}{s} -> ", .{ sym_link_style, entry.name, reset_style });
            if (prefix) |pfx| {
                const dir_style = getSimpleKind(.directory);
                output.print("{s}{s}", .{ dir_style, pfx });
                if (pfx[pfx.len - 1] != '/') output.printAsciiChar('/', .{});
            }
            output.print("{s}{s}{s}\n", .{ style, basename, reset_style });
        } else {
            output.print("{s}{s}{s} -> {s}\n", .{ bad_link_style, entry.name, reset_style, path });
        }
    } else |err| {
        output.print("{s}{s}{s} -> {s}error:{s} {t}", .{
            sym_link_style,
            entry.name,
            reset_style,
            error_style,
            reset_style,
            err,
        });
    }
}

/// Assume called after updating `detail`.
///
/// Returns .{ orginal_color, target_color(symlink) }.
pub fn get(entry: Dir.Entry) struct { []const u8, ?[]const u8 } {
    if (entry.kind == .sym_link) {} else return .{ getNotSymLink(entry), null };
}

fn getSymlink() struct { []const u8, ?[]const u8 } {}

fn getNotSymLink(entry: Dir.Entry) []const u8 {
    if (control.no_color) return reset_style;

    switch (entry.kind) {
        .file => getFile(entry.name),
        .sym_link => unreachable,

        .block_device => block_device_style,
        .character_device => character_device_style,
        .directory => directory_style,
        .named_pipe => named_pipe_style,
        .unix_domain_socket => unix_domain_socket_style,
        .door => door_style,
        else => reset_style, //.event_port .whiteout .unknown
    }
}

fn getFile(name: []const u8) []const u8 {
    if (detail.is_executable) return executable_style;

    const f_ext = Dir.path.extension(name);
    for (media_extensions) |ext| {
        if (eql(u8, f_ext, ext)) return media_style;
    }
    for (archive_extensions) |ext| {
        if (eql(u8, f_ext, ext)) return archive_style;
    }

    return reset_style;
}

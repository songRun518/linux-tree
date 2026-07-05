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
pub const symlink_style = "\x1b[36m";
pub const bad_link_style = "\x1b[31m";
pub const reset_style = "\x1b[0m";
pub const error_style = "\x1b[1;33m";

pub const executable_style = "\x1b[1;32m";

pub fn getNotSymLink(entry: Dir.Entry) []const u8 {
    if (control.no_color) return reset_style;

    return switch (entry.kind) {
        .file => getFile(entry.name),
        .sym_link => unreachable,

        .block_device => block_device_style,
        .character_device => character_device_style,
        .directory => directory_style,
        .named_pipe => named_pipe_style,
        .unix_domain_socket => unix_domain_socket_style,
        .door => door_style,
        else => reset_style, //.event_port .whiteout .unknown
    };
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

const media_style = "\x1b[1;35m";
const archive_style = "\x1b[1;35m";

const media_extensions = [_][]const u8{
    ".png", ".jpg", ".jpeg", ".gif", ".webp", ".svg", ".bmp", ".ico",  ".tiff",
    ".mp3", ".wav", ".flac", ".ogg", ".m4a",  ".aac", ".mid", ".wma",  ".mp4",
    ".mkv", ".mov", ".webm", ".avi", ".wmv",  ".flv", ".mpg", ".mpeg",
};
const archive_extensions = [_][]const u8{
    ".7z", ".xz", ".zip", ".tar", ".gz", ".bz2", ".rar", ".iso", ".lzma", ".cab",
};

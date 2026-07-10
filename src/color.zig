const std = @import("std");
const Allocator = std.mem.Allocator;
const Io = std.Io;
const Dir = Io.Dir;
const File = Io.File;
const eql = std.mem.eql;

const control = @import("main.zig").control;
const detail = @import("detail.zig");
const output = @import("output.zig");

pub const block_device_style = "\x1b[1;33m";
pub const character_device_style = "\x1b[1;33m";
pub const directory_style = "\x1b[34m";
pub const named_pipe_style = "\x1b[1;33m";
pub const unix_domain_socket_style = "\x1b[1;35m";
pub const door_style = "\x1b[1;36m";
pub const symlink_style = "\x1b[36m";

pub const bad_link_style = "\x1b[31m";
pub const reset_style = "\x1b[0m";
pub const error_style = "\x1b[1;33m";
pub const executable_style = "\x1b[1;32m";

/// Asserts `kind` is not **file** or **sym_link**.
pub fn getSimpleKind(kind: File.Kind) []const u8 {
    if (control.no_color) return reset_style;

    return switch (kind) {
        .file, .sym_link => unreachable,

        .block_device => block_device_style,
        .character_device => character_device_style,
        .directory => directory_style,
        .named_pipe => named_pipe_style,
        .unix_domain_socket => unix_domain_socket_style,
        .door => door_style,
        else => reset_style, //.event_port .whiteout .unknown
    };
}

/// Asserts `entry` is not **sym_link**.
pub fn getNotSymLink(entry: Dir.Entry) []const u8 {
    if (control.no_color) return reset_style;

    return switch (entry.kind) {
        .sym_link => unreachable,
        .file => getFile(entry.name),
        else => |k| getSimpleKind(k),
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

const media_style = "\x1b[35m";
const media_extensions = [_][]const u8{
    ".png", ".jpg",  ".jpeg", ".gif",  ".webp", ".svg",  ".bmp",  ".ico", ".tiff",
    ".tif", ".avif", ".heic", ".heif", ".raw",  ".cr2",  ".nef",  ".arw", ".dng",
    ".psd", ".ai",   ".eps",  ".mp3",  ".wav",  ".flac", ".ogg",  ".m4a", ".aac",
    ".mid", ".wma",  ".alac", ".opus", ".wv",   ".dsf",  ".dff",  ".mp4", ".mkv",
    ".mov", ".webm", ".avi",  ".wmv",  ".flv",  ".mpg",  ".mpeg", ".m4v", ".3gp",
    ".3g2", ".ogv",  ".ts",   ".m2ts", ".mts",
};
const archive_style = "\x1b[1;31m";
const archive_extensions = [_][]const u8{
    ".7z",  ".xz",  ".zip",  ".tar", ".gz",  ".bz2", ".rar",  ".iso",   ".lzma", ".cab",
    ".zst", ".lz",  ".lzh",  ".arj", ".ace", ".arc", ".pak",  ".z",     ".tgz",  ".tbz2",
    ".tlz", ".txz", ".tzst", ".img", ".dmg", ".vhd", ".vmdk", ".qcow2",
};

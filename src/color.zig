const std = @import("std");
const Allocator = std.mem.Allocator;
const Io = std.Io;
const Dir = Io.Dir;
const File = Io.File;
const eql = std.mem.eql;

const control = @import("main.zig").control;
const detail = @import("detail.zig");
const stdout = @import("stdout.zig");

const block_device_style = "\x1b[1;33m";
const character_device_style = "\x1b[1;33m";
const directory_style = "\x1b[34m";
const named_pipe_style = "\x1b[1;33m";
const unix_domain_socket_style = "\x1b[1;35m";
const door_style = "\x1b[1;36m";
const symlink_style = "\x1b[36m";

const bad_link_style = "\x1b[4;31m";
const reset_style = "\x1b[0m";
const error_style = "\x1b[1;33m";
const executable_style = "\x1b[1;32m";

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

pub inline fn getReset() [:0]const u8 {
    if (control.no_color) return "";
    return reset_style;
}

pub inline fn getError() [:0]const u8 {
    if (control.no_color) return "";
    return error_style;
}

pub inline fn getTargetPrefix() [:0]const u8 {
    if (control.no_color) return "";
    return if (detail.isBadLink())
        bad_link_style
    else
        directory_style;
}

/// Assumes called after updating detail.
pub inline fn getTarget() [:0]const u8 {
    if (control.no_color) return "";
    return if (detail.isBadLink())
        bad_link_style
    else if (detail.isTargetExecutable())
        executable_style
    else
        getSimple(detail.targetKind());
}

/// Treats file as the normal(reset style).
pub inline fn getSimple(kind: File.Kind) [:0]const u8 {
    if (control.no_color) return "";

    return switch (kind) {
        .block_device => block_device_style,
        .character_device => character_device_style,
        .directory => directory_style,
        .named_pipe => named_pipe_style,
        .unix_domain_socket => unix_domain_socket_style,
        .door => door_style,
        .sym_link => symlink_style,
        // .file .event_port .whiteout .unknown
        else => reset_style,
    };
}

/// Assumes called after updating detail.
pub inline fn get(entry: Dir.Entry) [:0]const u8 {
    if (control.no_color) return "";
    return if (entry.kind == .file) if (detail.isOriginExecutable()) executable_style else ext: {
        const f_ext = Dir.path.extension(entry.name);
        for (media_extensions) |ext| {
            if (eql(u8, f_ext, ext)) break :ext media_style;
        }
        for (archive_extensions) |ext| {
            if (eql(u8, f_ext, ext)) break :ext archive_style;
        }
        break :ext reset_style;
    } else getSimple(entry.kind);
}

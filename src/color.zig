const std = @import("std");
const Allocator = std.mem.Allocator;
const Io = std.Io;
const File = Io.File;
const findScalarPos = std.mem.findScalarPos;
const tokenizeScalar = std.mem.tokenizeScalar;
const containsAtLeastScalar2 = std.mem.containsAtLeastScalar2;
const StringHashMap = std.StringHashMap;

const root = @import("root");
const Info = root.Info;

const black = "30";
const red = "31";
const green = "32";
const yellow = "33";
const blue = "34";
const magenta = "35";
const cyan = "36";
const white = "37";
const bright_black = "90";
const bright_red = "91";
const bright_green = "92";
const bright_yellow = "93";
const bright_blue = "94";
const bright_magenta = "95";
const bright_cyan = "96";
const bright_white = "97";

const bold = "1";
const dim = "2";
const reset__ = "0";

fn compose(comptime effect: []const u8, comptime color: []const u8) []const u8 {
    comptime return effect ++ ";" ++ color;
}

var color_map: StringHashMap([]const u8) = undefined;

pub fn init(allocator: Allocator) !void {
    const media = comptime [_][]const u8{
        ".png", ".jpg", ".jpeg", ".gif", ".webp", ".svg", ".bmp", ".ico",  ".tiff",
        ".mp3", ".wav", ".flac", ".ogg", ".m4a",  ".aac", ".mid", ".wma",  ".mp4",
        ".mkv", ".mov", ".webm", ".avi", ".wmv",  ".flv", ".mpg", ".mpeg",
    };

    const archive = comptime [_][]const u8{
        ".7z", ".xz", ".zip", ".tar", ".gz", ".bz2", ".rar", ".iso", ".lzma", ".cab",
    };

    color_map = .init(allocator);
    errdefer color_map.deinit();

    for (media) |e| {
        try color_map.put(
            e,
            comptime compose(bold, magenta),
        );
    }
    for (archive) |e| {
        try color_map.put(
            e,
            comptime compose(bold, yellow),
        );
    }
}

pub fn deinit() void {
    color_map.deinit();
}

/// Assumes `permissions` is not null when `kind` is file.
pub fn get(info: Info) ![]const u8 {
    return switch (info.kind) {
        .block_device => yellow,
        .character_device => yellow,
        .directory => comptime compose(bold, blue),
        .named_pipe => yellow,
        .unix_domain_socket => magenta,
        .door => magenta,
        .sym_link => if (info.is_bad_link) red else comptime compose(
            bold,
            cyan,
        ),
        .file => f: {
            if (info.is_executable) break :f comptime compose(bold, green);

            break :f color_map.get(std.fs.path.extension(info.name)) orelse reset__;
        },
        // .event_port
        // .whiteout
        // .unknown
        else => reset__,
    };
}

pub fn set(w: *Io.Writer, option: Info) !void {
    try w.print("\x1b[{s}m", .{try get(option)});
}

/// Assume `kind` is not sym_link or file.
pub fn setByKind(w: *Io.Writer, kind: File.Kind) !void {
    const info: Info = .{
        .kind = kind,

        .name = "",
        .is_bad_link = false,
        .is_executable = false,
        .target_is_executable = false,
        .target_kind = null,
        .target_path = null,
    };
    try w.print("\x1b[{s}m", .{try get(info)});
}

pub fn reset(w: *Io.Writer) !void {
    try w.writeAll("\x1b[0m");
}

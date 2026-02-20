const std = @import("std");
const Allocator = std.mem.Allocator;
const Io = std.Io;
const File = Io.File;
const findScalarPos = std.mem.findScalarPos;
const tokenizeScalar = std.mem.tokenizeScalar;
const eql = std.mem.eql;
const containsAtLeastScalar2 = std.mem.containsAtLeastScalar2;
const StringHashMap = std.StringHashMap;
const assert = std.debug.assert;

const root = @import("root");
const Info = root.Info;

var color_map_buffer: []const u8 = undefined;
/// Its keys and values reference to `buffer`.
var color_map: StringHashMap([]const u8) = undefined;

fn initConcurrently(arena: Allocator, io: Io) !void {
    const result = try std.process.run(
        arena,
        io,
        .{ .argv = &.{"dircolors"} },
    );
    defer arena.free(result.stderr);

    color_map_buffer = result.stdout;
    color_map = .init(arena);
    is_deinit_safe = true;

    const si = 1 + findScalarPos(u8, color_map_buffer, 0, '\'').?;
    const ei = findScalarPos(u8, color_map_buffer, si, '\'').?;
    var tokens = tokenizeScalar(u8, color_map_buffer[si..ei], ':');
    while (tokens.next()) |token| {
        const delimiter_pos = findScalarPos(u8, token, 0, '=').?;
        const kind_or_fmt = token[0..delimiter_pos];
        const color_code = token[delimiter_pos + 1 ..];

        const key =
            if (containsAtLeastScalar2(u8, kind_or_fmt, '*', 1)) kind_or_fmt[1..] //
            else kind_or_fmt;
        try color_map.put(key, color_code);
    }
    is_future_done = true;
}

var await_io: Io = undefined;
var future: Io.Future(@typeInfo(@TypeOf(initConcurrently)).@"fn".return_type.?) = undefined;
var is_future_done = false;

pub fn init(arena: Allocator, io: Io) !void {
    await_io = io;
    future = try io.concurrent(initConcurrently, .{ arena, io });
}

var is_deinit_safe = false;

pub fn deinit(arena: Allocator) void {
    if (is_deinit_safe) {
        arena.free(color_map_buffer);
        color_map.deinit();
    }
}

pub const Option = struct {
    kind: File.Kind,
    is_bad_symlink: bool,
    is_executable: bool,
    extension: ?[]const u8,

    pub fn fromInfo(info: Info) @This() {
        return .{
            .kind = info.kind,
            .is_bad_symlink = info.is_bad_symlink,
            .is_executable = info.is_executable,
            .extension = info.extension,
        };
    }
};

/// Assumes `permissions` is not null when `kind` is file.
///
/// `format` is like ".xxx".
pub fn getColor(option: Option) ![]const u8 {
    const key = switch (option.kind) {
        .block_device => "bd",
        .character_device => "cd",
        .directory => "di",
        .named_pipe => "pi",
        .unix_domain_socket => "so",
        .door => "do",
        .sym_link => if (option.is_bad_symlink) "or" else "ln",
        .file => blk: {
            if (option.is_executable) break :blk "ex";
            if (option.extension) |ext| break :blk ext;
            break :blk "fi";
        },
        // .event_port
        // .whiteout
        // .unknown
        else => "rs",
    };
    if (!is_future_done) try future.await(await_io);
    return color_map.get(key) orelse color_map.get("rs").?;
}

pub fn setColor(stdout_writer: *Io.Writer, option: Option) !void {
    const color_code = try getColor(option);
    try stdout_writer.print("\x1b[{s}m", .{color_code});
}

/// Asserts `kind` is not sym_link or file.
pub fn setColorSimply(stdout_writer: *Io.Writer, kind: File.Kind) !void {
    assert(kind != .sym_link and kind != .file);
    var option: Option = undefined;
    option.kind = kind;
    const color_code = try getColor(option);
    try stdout_writer.print("\x1b[{s}m", .{color_code});
}

pub fn resetColor(stdout_writer: *Io.Writer) !void {
    try stdout_writer.writeAll("\x1b[0m");
}

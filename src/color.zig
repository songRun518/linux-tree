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

var color_map_buffer: []const u8 = undefined;
/// Its keys and values reference to `buffer`.
var color_map: StringHashMap([]const u8) = undefined;

fn initConcurrently(allocator: Allocator, io: Io) !void {
    const result = try std.process.run(
        allocator,
        io,
        .{ .argv = &.{"dircolors"} },
    );
    defer allocator.free(result.stderr);

    color_map_buffer = result.stdout;
    color_map = .init(allocator);
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

pub fn init(allocator: Allocator, io: Io) !void {
    await_io = io;
    future = try io.concurrent(initConcurrently, .{ allocator, io });
}

var is_deinit_safe = false;

pub fn deinit(allocator: Allocator) void {
    if (is_deinit_safe) {
        allocator.free(color_map_buffer);
        color_map.deinit();
    }
}

pub const Option = struct {
    kind: File.Kind,
    is_bad_link: bool,
    is_executable: bool,
    extension: ?[]const u8,

    pub fn fromInfo(info: Info) @This() {
        return .{
            .kind = info.kind,
            .is_bad_link = info.is_bad_link,
            .is_executable = info.is_executable,
            .extension = info.extension,
        };
    }
};

/// Assumes `permissions` is not null when `kind` is file.
///
/// `format` is like ".xxx".
pub fn get(option: Option) ![]const u8 {
    const key = switch (option.kind) {
        .block_device => "bd",
        .character_device => "cd",
        .directory => "di",
        .named_pipe => "pi",
        .unix_domain_socket => "so",
        .door => "do",
        .sym_link => if (option.is_bad_link) "or" else "ln",
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

pub fn set(stdout_writer: *Io.Writer, option: Option) !void {
    const color_code = try get(option);
    try stdout_writer.print("\x1b[{s}m", .{color_code});
}

/// Assume `kind` is not sym_link or file.
pub fn setByKind(stdout_writer: *Io.Writer, kind: File.Kind) !void {
    var option: Option = undefined;
    option.kind = kind;
    const color_code = try get(option);
    try stdout_writer.print("\x1b[{s}m", .{color_code});
}

pub fn reset(stdout_writer: *Io.Writer) !void {
    try stdout_writer.writeAll("\x1b[0m");
}

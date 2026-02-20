const std = @import("std");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;
const Io = std.Io;
const Dir = Io.Dir;
const File = Io.File;

pub const Args = @import("Args.zig");
pub const Info = @import("Info.zig");
pub const color = @import("color.zig");

pub fn main(init: std.process.Init) !void {
    const arena = if (builtin.mode == .Debug) init.gpa else init.arena.allocator();
    const io = init.io;

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_file_writer = File.stdout().writer(io, &stdout_buffer);
    const stdout_writer = &stdout_file_writer.interface;

    const args = Args.parse(arena, init.minimal.args) catch |err| {
        if (err == error.Exit) return;
        return err;
    };
    defer args.deinit(arena);

    try color.init(arena, io);
    defer color.deinit(arena);

    const cwd = try Dir.cwd().openDir(
        io,
        ".",
        .{ .iterate = true },
    );
    defer cwd.close(io);

    for (args.dir_paths) |dir_path| {
        try color.setColorSimply(stdout_writer, .directory);
        try stdout_writer.print("{s}\n", .{dir_path});
        try color.resetColor(stdout_writer);

        const dir = try cwd.openDir(io, dir_path, .{ .iterate = true });
        defer dir.close(io);
        try printTree(arena, io, dir, &args, &.{}, stdout_writer, 1);
    }
    try stdout_file_writer.flush();
}

fn printTree(
    arena: Allocator,
    io: Io,
    dir: Dir,
    args: *const Args,
    prev_chars: []const u21,
    stdout_writer: *Io.Writer,
    level: u64,
) !void {
    var information: std.ArrayList(Info) = .empty;
    defer {
        for (information.items) |i| i.deinit(arena);
        information.deinit(arena);
    }
    var it = dir.iterateAssumeFirstIteration();
    while (try it.next(io)) |entry| {
        if (!args.list_all and entry.name[0] == '.') continue;

        if (Info.init(arena, io, dir, entry) catch |err| switch (err) {
            error.FileLostWhileProcessing => null,
            else => return err,
        }) |info| try information.append(arena, info);
    }
    std.mem.sort(Info, information.items, {}, Info.lessThan);

    for (information.items, 0..) |info, idx| {
        for (prev_chars) |char| {
            try stdout_writer.print("{u}{1c}{1c}{1c}", .{ char, ' ' });
        }
        try stdout_writer.print(
            "{u}{1u}{1u} ",
            .{ @as(u21, if (idx == information.items.len - 1) '└' else '├'), '─' },
        );
        try printInfo(stdout_writer, info);
        try stdout_writer.printAsciiChar('\n', .{});

        if (level < args.level orelse std.math.maxInt(u64) and info.kind == .directory) {
            const new_dir = try dir.openDir(
                io,
                info.name,
                .{ .iterate = true, .follow_symlinks = false },
            );
            defer new_dir.close(io);

            const new_prev_chars = try arena.alloc(u21, prev_chars.len + 1);
            defer arena.free(new_prev_chars);
            @memcpy(new_prev_chars[0..prev_chars.len], prev_chars);
            new_prev_chars[new_prev_chars.len - 1] = if (idx == information.items.len - 1) ' ' else '│';

            try printTree(
                arena,
                io,
                new_dir,
                args,
                new_prev_chars,
                stdout_writer,
                level + 1,
            );
        }
    }
}

fn printInfo(stdout_writer: *Io.Writer, info: Info) !void {
    try color.setColor(stdout_writer, .fromInfo(info));
    try stdout_writer.print("{s}", .{info.name});
    try color.resetColor(stdout_writer);

    if (info.kind == .sym_link and !info.is_bad_symlink) {
        try stdout_writer.print(" -> ", .{});

        try color.setColor(stdout_writer, .{
            .kind = info.target_kind.?,
            .is_bad_symlink = info.is_bad_symlink,
            .is_executable = info.target_is_executable,
            .extension = undefined,
        });
        try stdout_writer.print("{s}", .{info.target_path.?});
        try color.resetColor(stdout_writer);
    }
}

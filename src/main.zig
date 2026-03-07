const std = @import("std");
const Allocator = std.mem.Allocator;
const Io = std.Io;
const Dir = Io.Dir;
const File = Io.File;

pub const Args = @import("Args.zig");
pub const Info = @import("Info.zig");
pub const color = @import("color.zig");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const io = init.io;

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_file_writer = File.stdout().writer(io, &stdout_buffer);
    const stdout_writer = &stdout_file_writer.interface;

    const args = Args.parse(allocator, init.minimal.args) catch |err| {
        if (err == error.Exit) return;
        return err;
    };
    defer args.deinit(allocator);

    try color.init(allocator, io);
    defer color.deinit(allocator);

    const cwd = try Dir.cwd().openDir(
        io,
        ".",
        .{ .iterate = true },
    );
    defer cwd.close(io);

    for (args.dir_paths) |dir_path| {
        try color.setByKind(stdout_writer, .directory);
        try stdout_writer.print("{s}\n", .{dir_path});
        try color.reset(stdout_writer);

        const dir = try cwd.openDir(io, dir_path, .{ .iterate = true });
        defer dir.close(io);
        try printTree(allocator, io, dir, &args, stdout_writer, 1);
    }
    try stdout_file_writer.flush();
}

var prev_branch_buffer: [std.fs.max_path_bytes]u21 = undefined;

fn printTree(
    allocator: Allocator,
    io: Io,
    dir: Dir,
    args: *const Args,
    stdout_writer: *Io.Writer,
    level: u64,
) !void {
    const prev_branch_buffer_index = level - 1; // It means index to modify.
    var information: std.ArrayList(Info) = .empty;
    defer {
        for (information.items) |i| i.deinit(allocator);
        information.deinit(allocator);
    }
    var it = dir.iterateAssumeFirstIteration();
    while (try it.next(io)) |entry| {
        if (!args.list_all and entry.name[0] == '.') continue;

        if (Info.init(allocator, io, dir, entry) catch |err| switch (err) {
            error.FileLostWhileProcessing => null,
            else => return err,
        }) |info| try information.append(allocator, info);
    }
    std.mem.sort(Info, information.items, {}, Info.lessThan);

    for (information.items, 0..) |info, idx| {
        for (0..prev_branch_buffer_index) |index| {
            try stdout_writer.print("{u}{1c}{1c}{1c}", .{ prev_branch_buffer[index], ' ' });
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

            prev_branch_buffer[prev_branch_buffer_index] = if (idx == information.items.len - 1) ' ' else '│';

            try printTree(
                allocator,
                io,
                new_dir,
                args,
                stdout_writer,
                level + 1,
            );
        }
    }
}

fn printInfo(stdout_writer: *Io.Writer, info: Info) !void {
    try color.set(stdout_writer, info);
    try stdout_writer.writeAll(info.name);
    try color.reset(stdout_writer);

    if (info.kind == .sym_link and !info.is_bad_link) {
        try stdout_writer.writeAll(" -> ");

        if (std.fs.path.dirname(info.target_path.?)) |target_dir_path| {
            try color.setByKind(stdout_writer, .directory);
            try stdout_writer.print("{s}/", .{target_dir_path});
        }
        try color.set(stdout_writer, .{
            .kind = info.target_kind.?,
            .is_bad_link = info.is_bad_link,
            .is_executable = info.target_is_executable,

            .name = "",
            .target_kind = null,
            .target_path = null,
            .target_is_executable = false,
        });

        try stdout_writer.writeAll(std.fs.path.basename(info.target_path.?));
        try color.reset(stdout_writer);
    }
}

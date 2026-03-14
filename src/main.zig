const std = @import("std");
const Allocator = std.mem.Allocator;
const Io = std.Io;
const Dir = Io.Dir;
const File = Io.File;

pub const argparse = @import("argparse.zig");
pub const Info = @import("Info.zig");
pub const color = @import("color.zig");
pub const filter = struct {
    pub var list_all = false;
    pub var level: ?u16 = null;
};

var stdout_buffer: [Dir.max_path_bytes]u8 = undefined;

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const io = init.io;

    var fw = File.stdout().writer(io, &stdout_buffer);
    const w = &fw.interface;

    const dirpaths = argparse.x(
        allocator,
        init.minimal.args,
        w,
    ) catch |err| switch (err) {
        argparse.Error.Exit => {
            try fw.flush();
            return;
        },
        else => return err,
    };
    defer allocator.free(dirpaths);

    try color.init(allocator);
    defer color.deinit();

    const cwd = try Dir.cwd().openDir(
        io,
        ".",
        .{ .iterate = true },
    );
    defer cwd.close(io);

    for (dirpaths) |dirp| {
        try color.setByKind(w, .directory);
        try w.print("{s}\n", .{dirp});
        try color.reset(w);

        const dir = try cwd.openDir(io, dirp, .{ .iterate = true });
        defer dir.close(io);
        try printTree(allocator, io, dir, 1, w);
    }
    try fw.flush();
}

var prev_branch_buffer: [Dir.max_path_bytes]u21 = undefined;

fn printTree(
    allocator: Allocator,
    io: Io,
    dir: Dir,
    level: u64,
    w: *Io.Writer,
) !void {
    const prev_branch_buffer_index = level - 1; // It means index to modify.
    var information: std.ArrayList(Info) = .empty;
    defer {
        for (information.items) |i| i.deinit(allocator);
        information.deinit(allocator);
    }
    var it = dir.iterateAssumeFirstIteration();
    while (try it.next(io)) |entry| {
        if (!filter.list_all and entry.name[0] == '.') continue;

        if (Info.init(allocator, io, dir, entry) catch |err| switch (err) {
            error.FileLostWhileProcessing => null,
            else => return err,
        }) |info| try information.append(allocator, info);
    }
    std.mem.sort(Info, information.items, {}, Info.lessThan);

    for (information.items, 0..) |info, idx| {
        for (0..prev_branch_buffer_index) |index| {
            try w.print("{u}{1c}{1c}{1c}", .{ prev_branch_buffer[index], ' ' });
        }
        try w.print(
            "{u}{1u}{1u} ",
            .{ @as(u21, if (idx == information.items.len - 1) '└' else '├'), '─' },
        );
        try printInfo(w, info);
        try w.printAsciiChar('\n', .{});

        if (level < filter.level orelse std.math.maxInt(u16) and info.kind == .directory) {
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
                level + 1,
                w,
            );
        }
    }
}

fn printInfo(w: *Io.Writer, info: Info) !void {
    try color.set(w, info);
    try w.writeAll(info.name);
    try color.reset(w);

    if (info.kind == .sym_link and !info.is_bad_link) {
        try w.writeAll(" -> ");

        if (std.fs.path.dirname(info.target_path.?)) |target_dir_path| {
            try color.setByKind(w, .directory);
            try w.print("{s}/", .{target_dir_path});
        }
        try color.set(w, .{
            .kind = info.target_kind.?,
            .is_bad_link = info.is_bad_link,
            .is_executable = info.target_is_executable,

            .name = "",
            .target_kind = null,
            .target_path = null,
            .target_is_executable = false,
        });

        try w.writeAll(std.fs.path.basename(info.target_path.?));
        try color.reset(w);
    }
}

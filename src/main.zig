const std = @import("std");
const Allocator = std.mem.Allocator;
const Io = std.Io;
const Dir = Io.Dir;
const path = Dir.path;
const File = Io.File;

pub const argparse = @import("argparse.zig");
pub const color = @import("color.zig");
pub const Info = @import("Info.zig");

pub const filter = struct {
    pub var list_all = false;
    pub var level: ?u16 = null;
};

var stdout_buffer: [Dir.max_path_bytes]u8 = undefined;

pub fn main(init: std.process.Init) !void {
    const gpa = init.gpa;
    const io = init.io;

    var fw = File.stdout().writer(io, &stdout_buffer);
    const w = &fw.interface;

    const dirpaths = argparse.perform(
        gpa,
        init.minimal.args,
        w,
    ) catch |err| switch (err) {
        error.Exit => {
            try fw.flush();
            return;
        },
        else => return err,
    };
    defer gpa.free(dirpaths);

    try color.init(gpa);
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
        try printTree(gpa, io, dir, 1, w);
    }
    try fw.flush();
}

var prev_branch_buffer: [Dir.max_path_bytes]u21 = undefined;

fn printTree(
    gpa: Allocator,
    io: Io,
    dir: Dir,
    level: u64,
    w: *Io.Writer,
) !void {
    const prev_branch_buffer_index = level - 1; // It means index to modify.
    var information: std.ArrayList(Info) = .empty;
    defer {
        for (information.items) |i| i.deinit(gpa);
        information.deinit(gpa);
    }
    var it = dir.iterateAssumeFirstIteration();
    while (try it.next(io)) |entry| {
        if (!filter.list_all and entry.name[0] == '.') continue;

        if (Info.init(gpa, io, dir, entry) catch |err| switch (err) {
            error.Ignore => null,
            else => return err,
        }) |info| try information.append(gpa, info);
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

        if (level < filter.level orelse std.math.maxInt(u16) and info.kind == .directory) deepen: {
            const new_dir = dir.openDir(
                io,
                info.name,
                .{ .iterate = true, .follow_symlinks = false },
            ) catch |err| switch (err) {
                error.AccessDenied => break :deepen,
                else => return err,
            };
            defer new_dir.close(io);

            prev_branch_buffer[prev_branch_buffer_index] = if (idx == information.items.len - 1) ' ' else '│';

            try printTree(
                gpa,
                io,
                new_dir,
                level + 1,
                w,
            );
        }
    }
}

fn printInfo(w: *Io.Writer, info: Info) !void {
    try color.set(w, .fromInfo(info));
    try w.writeAll(info.name);
    try color.reset(w);

    if (info.kind == .sym_link and !info.is_bad_link) {
        const target = info.target.?;

        try w.writeAll(" -> ");

        if (path.dirname(target.path)) |t_dirpath| {
            try color.setByKind(w, .directory);
            try w.print("{s}/", .{t_dirpath});
        }
        try color.set(w, .{
            .name = path.basename(target.path),
            .kind = target.kind,
            .is_executable = target.is_executable,
            .is_bad_link = false,
        });

        try w.writeAll(path.basename(target.path));
        try color.reset(w);
    }
}

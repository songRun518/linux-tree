const Self = @This();

const std = @import("std");
const Allocator = std.mem.Allocator;
const Io = std.Io;
const Dir = Io.Dir;
const File = Io.File;
const pathExtension = std.fs.path.extension;

name: [:0]const u8,
/// References to `name`.
extension: ?[]const u8,

/// Does not follow the symlink.
kind: File.Kind,
/// Does not follow the symlink.
is_bad_symlink: bool,
/// Does not follows the symlink.
is_executable: bool,

/// Follows the symlink if it is, and target's kind does not follow the symlink.
target_kind: ?File.Kind,
target_path: ?[]const u8,
target_is_executable: bool,

pub fn lessThan(_: void, a: Self, b: Self) bool {
    return a.name[0] < b.name[0];
}

var read_link_buffer: [Dir.max_path_bytes]u8 = undefined;

fn checkExecutable(permissions: File.Permissions) !bool {
    var buffer: [128]u8 = undefined;
    const written = try std.fmt.bufPrint(&buffer, "{o}", .{@intFromEnum(permissions)});
    return try std.fmt.charToDigit(written[written.len - 3], 8) % 2 != 0;
}

pub const Error = error{FileLostWhileProcessing};

pub fn init(arena: Allocator, io: Io, dir: Dir, entry: Dir.Entry) !Self {
    var self: Self = .{
        .name = try arena.dupeZ(u8, entry.name),
        .extension = null,

        .kind = entry.kind,
        .is_bad_symlink = false,
        .is_executable = false,

        .target_kind = null,
        .target_path = null,
        .target_is_executable = false,
    };
    errdefer arena.free(self.name);

    self.extension = pathExtension(self.name);
    if (self.extension.?.len == 0) self.extension = null;

    if (self.kind == .sym_link) {
        if (dir.statFile(io, self.name, .{})) |stat| {
            self.target_kind = stat.kind;

            const len = try dir.readLink(io, self.name, &read_link_buffer);
            self.target_path = try arena.dupe(u8, read_link_buffer[0..len]);
            errdefer arena.free(self.target_path.?);

            self.target_is_executable = try checkExecutable(stat.permissions);
        } else |err| switch (err) {
            error.FileNotFound => {
                self.is_bad_symlink = true;
            },
            else => return err,
        }
    } else if (self.kind == .file) {
        const stat = dir.statFile(io, self.name, .{}) catch |err| switch (err) {
            error.FileNotFound => return error.FileLostWhileProcessing,
            else => return err,
        };
        self.is_executable = try checkExecutable(stat.permissions);
    }
    return self;
}

pub fn deinit(self: Self, arena: Allocator) void {
    arena.free(self.name);
    if (self.target_path) |p| arena.free(p);
}

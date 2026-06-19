const std = @import("std");
const Allocator = std.mem.Allocator;
const Io = std.Io;
const Dir = Io.Dir;
const File = Io.File;

const Self = @This();

name: [:0]const u8,

kind: File.Kind,
is_executable: bool,
is_bad_link: bool,
/// Exists if it isn't bad link.
target: ?Target,

/// Symlink's target infomation.
pub const Target = struct {
    kind: File.Kind,
    path: []const u8,
    is_executable: bool,
};

pub fn lessThan(_: void, a: Self, b: Self) bool {
    return std.mem.lessThan(u8, a.name, b.name);
}

var read_link_buffer: [Dir.max_path_bytes]u8 = undefined;

fn checkExecutable(permissions: File.Permissions) !bool {
    var buffer: [128]u8 = undefined;
    const written = try std.fmt.bufPrint(&buffer, "{o}", .{@intFromEnum(permissions)});
    return try std.fmt.charToDigit(written[written.len - 3], 8) % 2 != 0;
}

pub const Error = error{Ignore};

pub fn init(gpa: Allocator, io: Io, dir: Dir, entry: Dir.Entry) !Self {
    var self: Self = .{
        .name = try gpa.dupeSentinel(u8, entry.name, 0),

        .kind = entry.kind,
        .is_executable = false,
        .is_bad_link = false,

        .target = null,
    };
    errdefer gpa.free(self.name);

    if (self.kind == .sym_link) {
        if (dir.statFile(io, self.name, .{})) |stat| {
            const t_kind = stat.kind;

            const len = try dir.readLink(io, self.name, &read_link_buffer);
            const t_path = try gpa.dupe(u8, read_link_buffer[0..len]);
            errdefer gpa.free(t_path);

            const t_is_executable = try checkExecutable(stat.permissions);

            self.target = .{
                .kind = t_kind,
                .path = t_path,
                .is_executable = t_is_executable,
            };
        } else |err| switch (err) {
            // A simple handle strategy.
            error.SymLinkLoop, error.Unexpected, error.AccessDenied, error.FileNotFound => {
                self.is_bad_link = true;
            },
            else => return err,
        }
    } else if (self.kind == .file) {
        const stat = dir.statFile(io, self.name, .{}) catch |err| switch (err) {
            error.AccessDenied, error.FileNotFound => return error.Ignore,
            else => return err,
        };
        self.is_executable = try checkExecutable(stat.permissions);
    }
    return self;
}

pub fn deinit(self: Self, gpa: Allocator) void {
    gpa.free(self.name);
    if (self.target) |t| gpa.free(t.path);
}

const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    if (target.result.os.tag != .linux) {
        std.log.err("Please compile for linux", .{});
        return;
    }

    const exe = b.addExecutable(.{
        .name = "tree",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    if (optimize != .Debug) {
        exe.root_module.omit_frame_pointer = true;
        exe.root_module.strip = true;
        exe.lto = .full;
    }
    b.getInstallStep().dependOn(&b.addInstallArtifact(
        exe,
        .{ .dest_dir = .{ .override = .{
            .custom = if (optimize == .Debug) "dev" else "release",
        } } },
    ).step);
}

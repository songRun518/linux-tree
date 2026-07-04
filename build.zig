const std = @import("std");

const exe_name = "tree";

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    if (target.result.os.tag != .linux) {
        std.log.err("Please compile for linux", .{});
        return;
    }

    const exe = b.addExecutable(.{
        .name = exe_name,
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
    b.getInstallStep().dependOn(&b.addInstallArtifact(exe, .{
        .dest_sub_path = if (optimize == .Debug) exe_name ++ "-debug" else exe_name,
    }).step);
}

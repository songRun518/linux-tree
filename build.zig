const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const is_release = optimize != .Debug;

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
        .use_lld = true,
        .use_llvm = true,
    });
    if (is_release) {
        exe.root_module.strip = true;
        exe.lto = .full;
    }

    b.installArtifact(exe);
}

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
            .strip = optimize != .Debug,
            .omit_frame_pointer = true,
            .pic = false,
        }),
        .use_lld = true,
        .use_llvm = true,
        .linkage = .static,
    });
    if (optimize != .Debug) {
        exe.lto = .full;
        exe.link_function_sections = true;
        exe.link_data_sections = true;
        exe.link_gc_sections = true;
        exe.pie = false;
    }

    b.installArtifact(exe);
}

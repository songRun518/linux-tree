const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    std.debug.assert(target.result.os.tag == .linux);
    const optimize = b.standardOptimizeOption(.{});
    const strip = b.option(bool, "strip", "Strip all symbols");

    const exe = b.addExecutable(.{
        .name = "tree",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .strip = strip,
        }),
    });
    b.installArtifact(exe);

    exe.root_module.addAnonymousImport("bzz", .{
        .root_source_file = b.path("build.zig.zon"),
        .target = target,
        .optimize = optimize,
        .strip = strip,
    });

    const run_exe = b.addRunArtifact(exe);
    run_exe.step.dependOn(b.getInstallStep());
    if (b.args) |args| run_exe.addArgs(args);
    const run_step = b.step("run", "Run the executable");
    run_step.dependOn(&run_exe.step);
}

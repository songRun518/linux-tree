const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "tree",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    b.installArtifact(exe);

    const build_info = BuildInfo.parse(b.allocator) catch unreachable;
    defer build_info.deinit(b.allocator);
    const options = b.addOptions();
    options.addOption(BuildInfo, "build_info", build_info);
    exe.root_module.addOptions("options", options);

    const run_exe = b.addRunArtifact(exe);
    run_exe.step.dependOn(b.getInstallStep());
    if (b.args) |args| run_exe.addArgs(args);
    const run_step = b.step("run", "Run the executable");
    run_step.dependOn(&run_exe.step);
}

const BuildInfo = struct {
    version: []const u8,

    const zon_slice: [:0]const u8 = @embedFile("build.zig.zon");

    fn parse(allocator: std.mem.Allocator) !@This() {
        return try std.zon.parse.fromSliceAlloc(
            @This(),
            allocator,
            zon_slice,
            null,
            .{ .ignore_unknown_fields = true },
        );
    }

    fn deinit(self: @This(), allocator: std.mem.Allocator) void {
        allocator.free(self.version);
    }
};

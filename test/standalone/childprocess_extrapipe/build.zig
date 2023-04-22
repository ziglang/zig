const Builder = @import("std").build.Builder;

pub fn build(b: *Builder) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const child = b.addExecutable(.{
        .name = "child",
        .root_source_file = .{ .path = "child.zig" },
        .target = target,
        .optimize = optimize,
    });

    const parent = b.addExecutable(.{
        .name = "parent",
        .root_source_file = .{ .path = "parent.zig" },
        .target = target,
        .optimize = optimize,
    });
    const run_cmd = b.addRunArtifact(parent);
    run_cmd.expectExitCode(0);
    run_cmd.addArtifactArg(child);

    const test_step = b.step("test", "Test it");
    test_step.dependOn(&run_cmd.step);
}

pub fn build(b: *std.Build) !void {
    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});

    const overridden_runtime_pkg = b.dependency("overridden_runtime", .{});
    const overridden_buildtime_pkg = b.dependency("overridden_buildtime", .{});

    const overridden_runtime_module = overridden_runtime_pkg.module("module");
    const overridden_buildtime_module = overridden_buildtime_pkg.module("module");

    const test_step = b.step("test", "check package override behavior");
    b.default_step = test_step;

    {
        const exe = b.addExecutable(.{
            .name = "dep-override-test-runtime",
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        });
        exe.root_module.addImport("module", overridden_runtime_module);

        const run = b.addRunArtifact(exe);

        const step = b.step("runtime", "check error package is overridden at runtime");
        step.dependOn(&run.step);

        test_step.dependOn(&run.step);
    }

    {
        const exe = b.addExecutable(.{
            .name = "dep-override-test-buildtime",
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        });
        exe.root_module.addImport("module", overridden_buildtime_module);

        const run = b.addRunArtifact(exe);

        const step = b.step("buildtime", "check error package is overridden at buildtime");
        step.dependOn(&run.step);

        test_step.dependOn(&run.step);
    }
}

const std = @import("std");

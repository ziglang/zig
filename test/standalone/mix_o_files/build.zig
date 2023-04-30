const std = @import("std");

pub fn build(b: *std.Build) void {
    const test_step = b.step("test", "Test it");
    b.default_step = test_step;

    const optimize: std.builtin.OptimizeMode = .Debug;
    const target: std.zig.CrossTarget = .{};

    const obj_mod = b.createModule(.{
        .source_file = .{ .path = "base64.zig" },
    });
    const obj = b.addObject(.{
        .name = "base64",
        .main_module = obj_mod,
        .optimize = optimize,
        .target = target,
    });

    const exe = b.addExecutable(.{
        .name = "test",
        .main_module = b.createModule(.{}),
        .optimize = optimize,
        .target = target,
    });
    exe.addCSourceFile("test.c", &[_][]const u8{"-std=c99"});
    exe.addObject(obj);
    exe.linkSystemLibrary("c");

    b.default_step.dependOn(&exe.step);

    const run_cmd = b.addRunArtifact(exe);
    test_step.dependOn(&run_cmd.step);
}

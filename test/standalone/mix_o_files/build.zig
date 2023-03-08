const std = @import("std");

pub fn build(b: *std.Build) void {
    const test_step = b.step("test", "Test it");
    b.default_step = test_step;

    const optimize: std.builtin.OptimizeMode = .Debug;
    const target: std.zig.CrossTarget = .{};

    const obj = b.addObject(.{
        .name = "base64",
        .root_source_file = .{ .path = "base64.zig" },
        .optimize = optimize,
        .target = target,
    });

    const exe = b.addExecutable(.{
        .name = "test",
        .optimize = optimize,
        .target = target,
    });
    exe.addCSourceFile("test.c", &[_][]const u8{"-std=c99"});
    exe.addObject(obj);
    exe.linkSystemLibrary("c");

    b.default_step.dependOn(&exe.step);

    const run_cmd = exe.run();

    test_step.dependOn(&run_cmd.step);
}

const std = @import("std");

pub fn build(b: *std.Build) void {
    const test_step = b.step("test", "Test it");
    b.default_step = test_step;

    const optimize: std.builtin.OptimizeMode = .Debug;

    const foo = b.createModule(.{
        .source_file = .{ .path = "foo.zig" },
    });
    foo.dependencies.put("foo", foo) catch @panic("OOM");

    const exe = b.addExecutable(.{
        .name = "test",
        .root_source_file = .{ .path = "test.zig" },
        .optimize = optimize,
    });
    exe.addModule("foo", foo);

    const run = b.addRunArtifact(exe);
    test_step.dependOn(&run.step);
}

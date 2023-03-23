const std = @import("std");

pub fn build(b: *std.Build) void {
    const test_step = b.step("test", "Test it");
    b.default_step = test_step;

    const optimize: std.builtin.OptimizeMode = .Debug;

    const shared = b.createModule(.{
        .source_file = .{ .path = "shared.zig" },
    });

    const exe = b.addExecutable(.{
        .name = "test",
        .root_source_file = .{ .path = "test.zig" },
        .optimize = optimize,
    });
    exe.addAnonymousModule("foo", .{
        .source_file = .{ .path = "foo.zig" },
        .dependencies = &.{.{ .name = "shared", .module = shared }},
    });
    exe.addAnonymousModule("bar", .{
        .source_file = .{ .path = "bar.zig" },
        .dependencies = &.{.{ .name = "shared", .module = shared }},
    });

    const run = exe.run();

    test_step.dependOn(&run.step);
}

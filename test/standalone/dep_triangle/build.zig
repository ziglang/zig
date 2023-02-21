const std = @import("std");

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});

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
    exe.addModule("shared", shared);

    const run = exe.run();

    const test_step = b.step("test", "Test it");
    test_step.dependOn(&run.step);
}

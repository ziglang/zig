const std = @import("std");

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "test",
        .root_source_file = .{ .path = "test.zig" },
        .optimize = optimize,
    });
    exe.addAnonymousModule("foo", .{
        .source_file = .{ .path = "foo.zig" },
    });

    const run = exe.run();

    const test_step = b.step("test", "Test it");
    test_step.dependOn(&run.step);
}

const std = @import("std");

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});

    const foo = b.createModule(.{
        .source_file = .{ .path = "foo.zig" },
    });
    const bar = b.createModule(.{
        .source_file = .{ .path = "bar.zig" },
    });
    foo.dependencies.put("bar", bar) catch @panic("OOM");
    bar.dependencies.put("foo", foo) catch @panic("OOM");

    const exe = b.addExecutable(.{
        .name = "test",
        .root_source_file = .{ .path = "test.zig" },
        .optimize = optimize,
    });
    exe.addModule("foo", foo);

    const run = exe.run();

    const test_step = b.step("test", "Test it");
    test_step.dependOn(&run.step);
}

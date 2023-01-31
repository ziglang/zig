const std = @import("std");

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});

    const obj = b.addObject(.{
        .name = "base64",
        .root_source_file = .{ .path = "base64.zig" },
        .optimize = optimize,
        .target = .{},
    });

    const exe = b.addExecutable(.{
        .name = "test",
        .optimize = optimize,
    });
    exe.addCSourceFile("test.c", &[_][]const u8{"-std=c99"});
    exe.addObject(obj);
    exe.linkSystemLibrary("c");

    b.default_step.dependOn(&exe.step);

    const run_cmd = exe.run();

    const test_step = b.step("test", "Test the program");
    test_step.dependOn(&run_cmd.step);
}

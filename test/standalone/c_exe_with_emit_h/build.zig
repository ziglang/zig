const std = @import("std");

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});

    const lib = b.addSharedLibrary(.{
        .name = "math",
        .root_source_file = .{ .path = "math.zig" },
        .version = .{ .major = 1, .minor = 0, .patch = 0 },
        .target = target,
        .optimize = optimize,
    });
    lib.emit_h = true;

    const exe = b.addExecutable(.{
        .name = "main",
    });
    exe.addCSourceFile("main.c", &[_][]const u8{"-std=c99"});
    exe.linkLibrary(lib);
    exe.linkSystemLibrary("c");

    b.default_step.dependOn(&exe.step);

    const run_cmd = exe.run();

    const test_step = b.step("test", "Test the program");
    test_step.dependOn(&run_cmd.step);
}

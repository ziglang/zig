const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = .{
        .cpu_arch = .x86_64,
        .os_tag = .windows,
        .abi = .msvc,
    };
    const optimize = b.standardOptimizeOption(.{});
    const obj = b.addObject(.{
        .name = "issue_5825",
        .root_source_file = .{ .path = "main.zig" },
        .optimize = optimize,
        .target = target,
    });

    const exe = b.addExecutable(.{
        .name = "issue_5825",
        .optimize = optimize,
        .target = target,
    });
    exe.subsystem = .Console;
    exe.linkSystemLibrary("kernel32");
    exe.linkSystemLibrary("ntdll");
    exe.addObject(obj);

    const test_step = b.step("test", "Test the program");
    test_step.dependOn(&exe.step);
}

const std = @import("std");

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "test",
        .root_source_file = .{ .path = "test.zig" },
        .optimize = optimize,
    });
    const lib = b.addStaticLibrary(.{
        .name = "lib",
        .target = .{},
        .optimize = optimize,
    });
    lib.addIncludePath("lib");
    lib.addCSourceFile("lib/lib.c", &.{""});
    lib.setOutputDir("lib_out");
    lib.install();

    var module = b.addModule("test_module", .{
        .source_file = .{
            .path = "test_module.zig",
        },
        .dependencies = &.{},
    });
    module.addIncludePath("lib");
    module.addLibraryPath("lib_out");
    module.linkSystemLibrary("lib");

    exe.addModule("test_module", module);
    exe.step.dependOn(&lib.step);

    const run = exe.run();
    b.default_step = &run.step;
}

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
    lib.setOutputDir("test/standalone/module_add_library_path/lib_out");
    lib.install();

    var module = b.addModule(.{
        .name = "test_module",
        .source_file = .{
            .path = "test_module.zig",
        },
        .dependencies = &.{},
    });
    module.addIncludePath("lib");
    module.addLibraryPath("test/standalone/module_add_library_path/lib_out");
    module.linkSystemLibrary("lib");

    exe.addModule("test_module", module);
    exe.step.dependOn(&lib.step);

    const run = exe.run();

    const test_step = b.step("test", "Test it");
    test_step.dependOn(&run.step);
}

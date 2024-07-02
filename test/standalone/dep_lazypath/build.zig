const std = @import("std");

pub fn build(b: *std.Build) void {
    const test_step = b.step("test", "Test it");
    b.default_step = test_step;

    const optimize: std.builtin.OptimizeMode = .Debug;

    {
        const write_files = b.addWriteFiles();
        const generated_main_c = write_files.add("main.c", "");
        const exe = b.addExecutable(.{
            .name = "test",
            .target = b.graph.host,
            .optimize = optimize,
        });
        exe.addCSourceFiles(.{
            .root = generated_main_c.dirname(),
            .files = &.{"main.c"},
        });
        b.step("csourcefiles", "").dependOn(&exe.step);
        test_step.dependOn(&exe.step);
    }
    {
        const write_files = b.addWriteFiles();
        const dir = write_files.addCopyDirectory(b.path("inc"), "", .{});
        const exe = b.addExecutable(.{
            .name = "test",
            .root_source_file = b.path("inctest.zig"),
            .target = b.graph.host,
            .optimize = optimize,
        });
        exe.addIncludePath(dir);
        b.step("copydir", "").dependOn(&exe.step);
        test_step.dependOn(&exe.step);
    }
}

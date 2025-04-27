pub fn build(b: *std.Build) void {
    // To avoid having to explicitly link required system libraries into the final test
    // executable (e.g. ntdll on Windows), we'll just link everything with libc here.

    const test_obj = b.addTest(.{
        .emit_object = true,
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = b.graph.host,
            .link_libc = true,
        }),
    });

    const test_exe_mod = b.createModule(.{
        .root_source_file = null,
        .target = b.graph.host,
        .link_libc = true,
    });
    test_exe_mod.addObject(test_obj);
    const test_exe = b.addExecutable(.{
        .name = "test",
        .root_module = test_exe_mod,
    });

    const test_step = b.step("test", "Test the program");
    b.default_step = test_step;

    const test_run = b.addRunArtifact(test_exe);
    test_step.dependOn(&test_run.step);
}

const std = @import("std");

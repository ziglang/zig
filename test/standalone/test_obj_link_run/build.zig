pub fn build(b: *std.Build) void {
    const is_windows = b.graph.host.result.os.tag == .windows;

    const test_obj = b.addTest(.{
        .emit_object = true,
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = b.graph.host,
        }),
    });
    if (is_windows) {
        test_obj.linkSystemLibrary("ntdll");
        test_obj.linkSystemLibrary("kernel32");
    }

    const test_exe_mod = b.createModule(.{
        .root_source_file = null,
        .target = b.graph.host,
    });
    test_exe_mod.addObject(test_obj);
    const test_exe = b.addExecutable(.{
        .name = "test",
        .root_module = test_exe_mod,
    });

    const test_step = b.step("test", "Test the program");
    b.default_step = test_step;

    const test_run = b.addRunArtifact(test_exe);
    if (!is_windows) {
        // https://github.com/ziglang/zig/issues/24867
        test_run.addCheck(.{ .expect_stderr_match = "All 3 tests passed." });
    }
    test_step.dependOn(&test_run.step);
}

const std = @import("std");

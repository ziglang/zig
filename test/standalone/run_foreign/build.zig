const std = @import("std");
const builtin = @import("builtin");
const Builder = std.build.Builder;

pub fn build(b: *Builder) void {
    const test_step = b.step("test", "Test the program");

    {
        const run_step = b.addSystemCommand(&[_][]const u8 {
            b.zig_exe,
            "build",
            "--build-file", b.pathFromRoot("buildhello.zig"),
            "run",
        });
        run_step.stdout_action = .{ .expect_exact = "hello\n" };
        test_step.dependOn(&run_step.step);
    }

    {
        const run_step = b.addSystemCommand(&[_][]const u8 {
            b.zig_exe,
            "build",
            "--build-file", b.pathFromRoot("buildhello.zig"),
            b.fmt("-Dtarget=native-{s}", .{if (builtin.os.tag == .windows) "linux" else "windows"}),
            // this tests that we don't need to provide "run" for the build to fail
        });
        run_step.expected_exit_code = 1;
        run_step.stderr_action = .{ .expect_matches = &[_][]const u8 {
            "Cannot run 'hello', incompatible target",
        } };
        test_step.dependOn(&run_step.step);
    }
}

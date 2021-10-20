const std = @import("std");
const Builder = std.build.Builder;

pub fn build(b: *Builder) !void {
    const test_step = b.step("test", "The test");

    {
        const run_step = b.addSystemCommand(&[_][]const u8{
            b.zig_exe,
            "build",
            "--build-file",
            "build2.zig",
        });
        run_step.stdout_action = .{ .expect_exact = "" };
        test_step.dependOn(&run_step.step);
    }

    {
        const run_step = b.addSystemCommand(&[_][]const u8{
            b.zig_exe,
            "build",
            "--build-file",
            "build2.zig",
            "-Dbadoption",
        });
        run_step.stderr_action = .{ .expect_exact = "error: got a bad build option!\n" };
        run_step.expected_exit_code = std.build.fail_fully_reported_exit_code;
        test_step.dependOn(&run_step.step);
    }

    b.default_step.dependOn(test_step);
}

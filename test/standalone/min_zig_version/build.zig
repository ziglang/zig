const std = @import("std");

pub fn build(b: *std.build.Builder) void {
    const test_step = b.step("test", "Run the test");

    {
        const run = testBuild(b, b.pathFromRoot("distant-future-dev-build.zig"));
        run.expected_exit_code = 1;
        run.stderr_action = .{ .expect_matches = &[_][]const u8{
            "error: zig is too old, have ",
            " but build.zig has min_zig_version 999.999.999-dev.999999+5735ce39ae5a9fb2bc2ac9f5a722276c291b28bc\n",
        } };
        test_step.dependOn(&run.step);
    }
    {
        const run = testBuild(b, b.pathFromRoot("distant-future-release-build.zig"));
        run.expected_exit_code = 1;
        run.stderr_action = .{ .expect_matches = &[_][]const u8{
            "error: zig is too old, have ",
            " but build.zig has min_zig_version 999.999.999\n",
        } };
        test_step.dependOn(&run.step);
    }
    {
        const build_zig = b.pathFromRoot("equal-version-build.zig");
        const write_file = b.addWriteFile(
            build_zig,
            b.fmt(
                \\//config min_zig_version {}
                \\const std = @import("std");
                \\pub fn build(b: *std.build.Builder) void {{ _ = b; }}
                \\
            ,
                .{@import("builtin").zig_version},
            ),
        );
        const run = testBuild(b, build_zig);
        run.stdout_action = .{ .expect_exact = "" };
        run.stderr_action = .{ .expect_exact = "" };
        run.step.dependOn(&write_file.step);
        test_step.dependOn(&run.step);
    }
}

fn testBuild(b: *std.build.Builder, build_file: []const u8) *std.build.RunStep {
    const run = b.addSystemCommand(&[_][]const u8{
        b.zig_exe,
        "build",
        "--build-file",
        build_file,
    });
    return run;
}

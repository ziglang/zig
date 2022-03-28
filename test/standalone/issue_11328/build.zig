const Builder = @import("std").build.Builder;

pub fn build(b: *Builder) void {
    const test_step = b.step("test", "Test the program");

    {
        const run = b.addSystemCommand(&[_][]const u8{
            b.zig_exe,
            "cc",
            "-nostdinc",
            b.pathFromRoot("hello.c"),
        });
        run.expected_exit_code = 1;
        run.stderr_action = .{ .expect_matches = &[_][]const u8{"'stdio.h' file not found"} };
        test_step.dependOn(&run.step);
    }

    b.default_step.dependOn(test_step);
}

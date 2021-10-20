const std = @import("std");
const Builder = std.build.Builder;

pub fn build(b: *Builder) !void {
    {
        const config_filename = b.pathFromRoot("config.zig");
        const config_file = try std.fs.cwd().createFile(config_filename, .{});
        defer config_file.close();
        try config_file.writer().writeAll(
            \\pub const step_name = "foo";
            \\
        );
    }

    const test_step = b.step("test", "Test the program");
    b.default_step.dependOn(test_step);

    {
        const build_step = b.addBuild(.{ .path = "buildconfigured.zig" }, .{});
        build_step.addArgs(b.build_args);
        test_step.dependOn(&build_step.step);
    }
    {
        const build_step = b.addBuild(.{ .path = "buildconfigured.zig" }, .{});
        build_step.addArg("foo");
        test_step.dependOn(&build_step.step);
    }
    {
        const build_step = b.addBuild(.{ .path = "buildconfigured.zig" }, .{});
        build_step.addArg("doesnotexist");
        build_step.expected_exit_code = 1;
        build_step.stderr_action = .{ .expect_matches = &[_][]const u8{
            "Cannot run step 'doesnotexist' because it does not exist",
        } };
        test_step.dependOn(&build_step.step);
    }
}

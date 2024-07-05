const std = @import("std");
const builtin = @import("builtin");

pub fn build(b: *std.Build) void {
    const test_step = b.step("test", "Run the enforce_zon_paths standalone test cases");
    b.default_step = test_step;

    inline for (&.{
        .{ "missing_zon", "error: path \"build.zig.zon\" is not included in" },
        .{ "missing_build_zig", "error: path \"build.zig\" is not included in" },
        .{ "path_with_dot_dot", "forbidden \"..\" found in path \"..\"" },
        .{ "missing_path", "error: path \"this_path_is_missing_from_zon\" is not included in" },
    }) |t| {
        const name = t[0];
        const error_msg = t[1];
        const run = b.addSystemCommand(&.{ b.graph.zig_exe, "build" });
        run.setCwd(b.path(name));
        run.addCheck(.{ .expect_stderr_match = error_msg });
        b.step(name, "Run the " ++ name ++ " test").dependOn(&run.step);
        test_step.dependOn(&run.step);
    }
}

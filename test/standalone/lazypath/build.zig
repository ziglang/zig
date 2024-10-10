const std = @import("std");

pub fn build(b: *std.Build) void {
    const test_step = b.step("test", "Test it");
    b.default_step = test_step;

    {
        const zig_build = addZigBuild(b);
        zig_build.addArg("-Dresolve-path-during-config");
        zig_build.addCheck(.{ .expect_stderr_match = "getPath called on LazyPath outside of any step's make function" });
        test_step.dependOn(&zig_build.step);
    }

    inline for (&.{
        // TODO: we should be able to assert an error regardless of the LazyPath kind
        //       but this requires more changes
        //"dangling_src_path",
        "dangling_generated",
        //"dangling_cwd_relative",
        //"dangling_dependency",
    }) |step_name| {
        const zig_build = addZigBuild(b);
        zig_build.addArg(step_name);
        const e = "getPath() was called on a GeneratedFile that wasn't built yet.";
        zig_build.addCheck(.{ .expect_stderr_match = e });
        test_step.dependOn(&zig_build.step);
    }
}

fn addZigBuild(b: *std.Build) *std.Build.Step.Run {
    return b.addSystemCommand(&.{
        b.graph.zig_exe,
        "build",
        "--build-file",
        b.pathFromRoot("example/build.zig"),
    });
}

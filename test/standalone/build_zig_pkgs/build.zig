const Builder = @import("std").build.Builder;

pub fn build(b: *Builder) void {
    const test_step = b.step("test", "Resolve android and test the zig build files");

    {
        const exe = b.addExecutable("no-android", "run.zig");
        exe.setBuildMode(b.standardReleaseOptions());
        const run = exe.run();
        run.addArg("pass");
        run.addArg("android not enabled, 'androidbuild' package not needed");
        run.addArg(b.zig_exe);
        run.addArg("build");
        run.addArg("--build-file");
        run.addArg("app-that-might-use-android/build.zig");
        test_step.dependOn(&run.step);
    }

    {
        const exe = b.addExecutable("missing-android", "run.zig");
        exe.setBuildMode(b.standardReleaseOptions());
        const run = exe.run();
        run.addArg("fail");
        run.addArg("missing package 'androidbuild'");
        run.addArg(b.zig_exe);
        run.addArg("build");
        run.addArg("--build-file");
        run.addArg("app-that-might-use-android/build.zig");
        run.addArg("-Dandroid");
        test_step.dependOn(&run.step);
    }

    {
        const exe = b.addExecutable("with-android-no-fastcompress", "run.zig");
        exe.setBuildMode(b.standardReleaseOptions());
        const run = exe.run();
        run.addArg("pass");
        run.addArg("we have and need the 'androidbuild' package");
        run.addArg(b.zig_exe);
        run.addArg("build");
        run.addArg("--build-file");
        run.addArg("app-that-might-use-android/build.zig");
        run.addArg("--pkg-begin");
        run.addArg("androidbuild");
        run.addArg("android/build.zig");
        run.addArg("--pkg-end");
        run.addArg("-Dandroid");
        test_step.dependOn(&run.step);
    }

    {
        const exe = b.addExecutable("with-android-missing-fastcompress", "run.zig");
        exe.setBuildMode(b.standardReleaseOptions());
        const run = exe.run();
        run.addArg("fail");
        run.addArg("-Dfastcompress requires the 'fastcompressor' package");
        run.addArg(b.zig_exe);
        run.addArg("build");
        run.addArg("--build-file");
        run.addArg("app-that-might-use-android/build.zig");
        run.addArg("--pkg-begin");
        run.addArg("androidbuild");
        run.addArg("android/build.zig");
        run.addArg("--pkg-end");
        run.addArg("-Dandroid");
        run.addArg("-Dfastcompress");
        test_step.dependOn(&run.step);
    }

    {
        const exe = b.addExecutable("with-android-and-fastcompress", "run.zig");
        exe.setBuildMode(b.standardReleaseOptions());
        const run = exe.run();
        run.addArg("fail");
        run.addArg("-Dfastcompress requires the 'fastcompressor' package");
        run.addArg(b.zig_exe);
        run.addArg("build");
        run.addArg("--build-file");
        run.addArg("app-that-might-use-android/build.zig");
        run.addArg("--pkg-begin");
        run.addArg("androidbuild");
        run.addArg("android/build.zig");
        run.addArg("--pkg-begin");
        run.addArg("fastcompress");
        run.addArg("fastcompress/build.zig");
        run.addArg("--pkg-end");
        run.addArg("--pkg-end");
        run.addArg("-Dandroid");
        run.addArg("-Dfastcompress");
        test_step.dependOn(&run.step);
    }

    {
        const exe = b.addExecutable("missing-comptime", "run.zig");
        exe.setBuildMode(b.standardReleaseOptions());
        const run = exe.run();
        run.addArg("fail");
        run.addArg("builtin.hasPkg MUST be called with comptime");
        run.addArg(b.zig_exe);
        run.addArg("build");
        run.addArg("--build-file");
        run.addArg("missing-comptime/build.zig");
        test_step.dependOn(&run.step);
    }

    {
        const exe = b.addExecutable("calling-haspkg-outside-build", "run.zig");
        exe.setBuildMode(b.standardReleaseOptions());
        const run = exe.run();
        run.addArg("fail");
        run.addArg("builtin.hasPkg is only available in build.zig");
        run.addArg(b.zig_exe);
        run.addArg("build-exe");
        run.addArg("calling-haspkg-outside-build.zig");
        test_step.dependOn(&run.step);
    }
}

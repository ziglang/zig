const Builder = @import("std").build.Builder;
const buildpkgs = @import("buildpkgs");

pub fn build(b: *Builder) void {
    if (comptime buildpkgs.has("androidbuild")) {
        const androidbuild = @import("androidbuild");
        androidbuild.makeApk(b);
    } else {
        const resolveandroid = b.addExecutable("resolveandroid", "resolveandroid.zig");
        resolveandroid.setBuildMode(b.standardReleaseOptions());
        const run_resolveandroid = resolveandroid.run();
        run_resolveandroid.addArg("expect-pass");
        run_resolveandroid.addArg(b.zig_exe);

        const test_build_error = b.addExecutable("test-build-error", "resolveandroid.zig");
        test_build_error.setBuildMode(b.standardReleaseOptions());
        const run_test_build_error = test_build_error.run();
        run_test_build_error.addArg("expect-fail");
        run_test_build_error.addArg(b.zig_exe);
        run_test_build_error.addArg("--build-file");
        run_test_build_error.addArg("invalid-build.zig");

        const test_step = b.step("test", "Resolve android and test the zig build files");
        test_step.dependOn(&run_resolveandroid.step);
        test_step.dependOn(&run_test_build_error.step);
    }
}

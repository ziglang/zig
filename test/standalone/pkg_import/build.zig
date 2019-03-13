const Builder = @import("std").build.Builder;

pub fn build(b: *Builder) void {
    const exe = b.addExecutable("test", "test.zig");
    exe.addPackagePath("my_pkg", "pkg.zig");

    // This is duplicated to test that you are allowed to call
    // b.standardReleaseOptions() twice.
    exe.setBuildMode(b.standardReleaseOptions());
    exe.setBuildMode(b.standardReleaseOptions());

    const run = exe.run();

    const test_step = b.step("test", "Test it");
    test_step.dependOn(&run.step);
}

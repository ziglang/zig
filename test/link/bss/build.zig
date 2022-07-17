const Builder = @import("std").build.Builder;

pub fn build(b: *Builder) void {
    const mode = b.standardReleaseOptions();
    const test_step = b.step("test", "Test");

    const exe = b.addExecutable("bss", "main.zig");
    b.default_step.dependOn(&exe.step);
    exe.setBuildMode(mode);

    const run = exe.run();
    run.expectStdOutEqual("0, 1, 0\n");
    test_step.dependOn(&run.step);
}

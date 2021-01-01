const Builder = @import("std").build.Builder;

pub fn build(b: *Builder) void {
    _ = b.standardReleaseOptions();

    const main = b.addExecutable("main", "main.zig");

    const run = main.run();
    run.clearEnvironment();

    const test_step = b.step("test", "Test it");
    test_step.dependOn(&run.step);
}

const Builder = @import("std").build.Builder;

pub fn build(b: *Builder) void {
    _ = b.standardReleaseOptions();

    const lib = b.addSharedLibrary("add", "add.zig", b.version(1, 0, 0));

    const main = b.addExecutable("main", "main.zig");

    const run = main.run();
    run.addArtifactArg(lib);

    const test_step = b.step("test", "Test the program");
    test_step.dependOn(&run.step);
}

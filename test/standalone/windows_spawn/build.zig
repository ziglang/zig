const Builder = @import("std").build.Builder;

pub fn build(b: *Builder) void {
    const mode = b.standardReleaseOptions();

    const hello = b.addExecutable("hello", "hello.zig");
    hello.setBuildMode(mode);

    const main = b.addExecutable("main", "main.zig");
    main.setBuildMode(mode);
    const run = main.run();
    run.addArtifactArg(hello);

    const test_step = b.step("test", "Test it");
    test_step.dependOn(&run.step);
}

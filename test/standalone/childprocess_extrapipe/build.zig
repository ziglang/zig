const Builder = @import("std").build.Builder;

pub fn build(b: *Builder) void {
    const mode = b.standardReleaseOptions();

    const child = b.addExecutable("child", "child.zig");
    child.setBuildMode(mode);

    const parent = b.addExecutable("parent", "parent.zig");
    parent.setBuildMode(mode);
    const run_cmd = parent.run();
    run_cmd.addArtifactArg(child);

    const test_step = b.step("test", "Test it");
    test_step.dependOn(&run_cmd.step);
}

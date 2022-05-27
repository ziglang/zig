const Builder = @import("std").build.Builder;

pub fn build(b: *Builder) void {
    const child = b.addExecutable("child", "child.zig");
    child.install();
    const parent = b.addExecutable("parent", "parent.zig");
    parent.install();
    const run_cmd = parent.run();
    run_cmd.step.dependOn(b.getInstallStep());
    const test_step = b.step("test", "Test it");
    test_step.dependOn(&run_cmd.step);
}

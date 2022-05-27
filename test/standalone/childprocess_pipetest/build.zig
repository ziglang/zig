const Builder = @import("std").build.Builder;

pub fn build(b: *Builder) void {
    const parent = b.addExecutable("parent", "parent.zig");
    const run_cmd = parent.run();
    run_cmd.addArg(b.zig_exe);
    const test_step = b.step("test", "Test it");
    test_step.dependOn(&run_cmd.step);
}

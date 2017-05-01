const Builder = @import("std").build.Builder;

pub fn build(b: &Builder) {
    const exe = b.addExecutable("test", "test.zig");
    exe.addPackagePath("my_pkg", "pkg.zig");

    const run = b.addCommand(".", b.env_map, exe.getOutputPath(), [][]const u8{});
    run.step.dependOn(&exe.step);

    const test_step = b.step("test", "Test it");
    test_step.dependOn(&run.step);
}

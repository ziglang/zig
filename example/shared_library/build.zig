const Builder = @import("std").build.Builder;

pub fn build(b: *Builder) void {
    const lib = b.addSharedLibrary("mathtest", "mathtest.zig", b.version(1, 0, 0));

    const exe = b.addCExecutable("test");
    exe.addCompileFlags([][]const u8{"-std=c99"});
    exe.addSourceFile("test.c");
    exe.linkLibrary(lib);

    b.default_step.dependOn(&exe.step);

    const run_cmd = b.addCommand(".", b.env_map, [][]const u8{exe.getOutputPath()});
    run_cmd.step.dependOn(&exe.step);

    const test_step = b.step("test", "Test the program");
    test_step.dependOn(&run_cmd.step);
}

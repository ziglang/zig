const Builder = @import("std").build.Builder;

pub fn build(b: *Builder) void {
    const obj = b.addObject("base64", "base64.zig");

    const exe = b.addCExecutable("test");
    exe.addCompileFlags([][]const u8{"-std=c99"});
    exe.addSourceFile("test.c");
    exe.addObject(obj);

    b.default_step.dependOn(&exe.step);

    const run_cmd = b.addCommand(".", b.env_map, [][]const u8{exe.getOutputPath()});
    run_cmd.step.dependOn(&exe.step);

    const test_step = b.step("test", "Test the program");
    test_step.dependOn(&run_cmd.step);
}

const Builder = @import("std").build.Builder;

pub fn build(b: *Builder) void {
    const obj = b.addObject("base64", "base64.zig");

    const exe = b.addExecutable("test", null);
    exe.addCSourceFile("test.c", &[_][]const u8{"-std=c99"});
    exe.addObject(obj);
    exe.linkSystemLibrary("c");

    b.default_step.dependOn(&exe.step);

    const run_cmd = exe.run();

    const test_step = b.step("test", "Test the program");
    test_step.dependOn(&run_cmd.step);
}

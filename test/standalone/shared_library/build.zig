const Builder = @import("std").build.Builder;

pub fn build(b: *Builder) void {
    const lib = b.addSharedLibrary("mathtest", "mathtest.zig", b.version(1, 0, 0));

    const exe = b.addExecutable("test", null);
    exe.addCSourceFile("test.c", &[_][]const u8{"-std=c99"});
    exe.linkLibrary(lib);
    exe.linkSystemLibrary("c");

    b.default_step.dependOn(&exe.step);

    const run_cmd = exe.run();

    const test_step = b.step("test", "Test the program");
    test_step.dependOn(&run_cmd.step);
}

const Builder = @import("std").build.Builder;

pub fn build(b: *Builder) void {
    const target = b.standardTargetOptions(.{});
    const lib = b.addSharedLibrary("mathtest", "mathtest.zig", b.version(1, 0, 0));
    lib.setTarget(target);

    const exe = b.addExecutable("test", null);
    exe.setTarget(target);
    exe.addCSourceFile("test.c", &[_][]const u8{"-std=c99"});
    exe.linkLibrary(lib);
    exe.linkSystemLibrary("c");

    b.default_step.dependOn(&exe.step);

    const run_cmd = exe.run();

    const test_step = b.step("test", "Test the program");
    test_step.dependOn(&run_cmd.step);
}

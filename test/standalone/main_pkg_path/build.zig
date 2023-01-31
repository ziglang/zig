const Builder = @import("std").build.Builder;

pub fn build(b: *Builder) void {
    const test_exe = b.addTest(.{
        .root_source_file = .{ .path = "a/test.zig" },
    });
    test_exe.setMainPkgPath(".");

    const test_step = b.step("test", "Test the program");
    test_step.dependOn(&test_exe.step);
}

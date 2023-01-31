const Builder = @import("std").build.Builder;

pub fn build(b: *Builder) void {
    const exe = b.addExecutable(.{
        .name = "issue_7030",
        .root_source_file = .{ .path = "main.zig" },
        .target = .{
            .cpu_arch = .wasm32,
            .os_tag = .freestanding,
        },
    });
    exe.install();
    b.default_step.dependOn(&exe.step);

    const test_step = b.step("test", "Test the program");
    test_step.dependOn(&exe.step);
}

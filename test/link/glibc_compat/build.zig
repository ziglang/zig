const std = @import("std");

pub fn build(b: *std.Build) void {
    const test_step = b.step("test", "Test");
    b.default_step = test_step;

    inline for (.{ "aarch64-linux-gnu.2.27", "aarch64-linux-gnu.2.34" }) |t| {
        const exe = b.addExecutable(.{
            .name = t,
            .root_source_file = .{ .path = "main.c" },
            .target = std.zig.CrossTarget.parse(
                .{ .arch_os_abi = t },
            ) catch unreachable,
        });
        exe.linkLibC();
        test_step.dependOn(&exe.step);
    }
}

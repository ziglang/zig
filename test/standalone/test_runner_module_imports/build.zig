const std = @import("std");

pub fn build(b: *std.Build) void {
    const module1 = b.createModule(.{ .source_file = .{ .path = "module1/main.zig" } });
    const module2 = b.createModule(.{
        .source_file = .{ .path = "module2/main.zig" },
        .dependencies = &.{.{ .name = "module1", .module = module1 }},
    });

    const t = b.addTest(.{
        .main_module = b.createModule(.{
            .source_file = .{ .path = "src/main.zig" },
            .dependencies = &.{
                .{ .name = "module2", .module = module2 },
            },
        }),
        .test_runner = "test_runner/main.zig",
    });

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&b.addRunArtifact(t).step);
    b.default_step = test_step;
}

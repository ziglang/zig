const std = @import("std");

pub fn build(b: *std.Build) void {
    const t = b.addTest(.{
        .root_source_file = b.path("src/main.zig"),
        .test_runner = b.path("test_runner/main.zig"),
    });

    const module1 = b.createModule(.{ .root_source_file = b.path("module1/main.zig") });
    const module2 = b.createModule(.{
        .root_source_file = b.path("module2/main.zig"),
        .imports = &.{.{ .name = "module1", .module = module1 }},
    });

    t.root_module.addImport("module2", module2);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&b.addRunArtifact(t).step);
    b.default_step = test_step;
}

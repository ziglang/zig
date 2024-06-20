const std = @import("std");

pub fn build(b: *std.Build) void {
    const module1 = b.createModule(.{
        .root_source_file = b.path("module1/main.zig"),
    });
    const module2 = b.createModule(.{
        .root_source_file = b.path("module2/main.zig"),
        .imports = &.{.{
            .name = "module1",
            .module = module1,
        }},
    });

    const main_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = b.graph.host,
        .imports = &.{.{
            .name = "module2",
            .module = module2,
        }},
    });

    const t = b.addTest2(.{
        .root_module = main_mod,
        .test_runner = b.path("test_runner/main.zig"),
    });

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&b.addRunArtifact(t).step);
    b.default_step = test_step;
}

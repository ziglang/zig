const std = @import("std");
const builtin = @import("builtin");

pub fn build(b: *std.Build) void {
    const test_step = b.step("test", "Test it");
    b.default_step = test_step;

    for ([_]bool{ false, true }) |use_llvm| {
        const main = b.addObject(.{
            .name = "main",
            .root_module = b.createModule(.{
                .root_source_file = b.path("main.zig"),
                .target = b.resolveTargetQuery(.{
                    .cpu_arch = .x86_64,
                    .os_tag = .linux,
                }),
            }),
            .use_llvm = use_llvm,
            .use_lld = use_llvm,
        });
        _ = main.getEmittedBin();
        test_step.dependOn(&main.step);
    }
}

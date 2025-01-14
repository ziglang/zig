const std = @import("std");

pub fn build(b: *std.Build) void {
    const test_step = b.step("test", "Test");
    b.default_step = test_step;

    const lib = b.addExecutable(.{
        .name = "lib",
        .root_module = b.createModule(.{
            .root_source_file = b.path("lib.zig"),
            .optimize = .Debug,
            .target = b.resolveTargetQuery(.{ .cpu_arch = .wasm32, .os_tag = .freestanding }),
        }),
    });
    lib.entry = .disabled;
    lib.bundle_ubsan_rt = false;
    lib.use_lld = false;
    lib.root_module.export_symbol_names = &.{ "foo", "bar" };
    // Object being linked has neither functions nor globals named "foo" or "bar" and
    // so these names correctly fail to be exported when creating an executable.
    lib.expect_errors = .{ .exact = &.{
        "error: manually specified export name 'foo' undefined",
        "error: manually specified export name 'bar' undefined",
    } };
    _ = lib.getEmittedBin();

    test_step.dependOn(&lib.step);
}

const std = @import("std");
const builtin = @import("builtin");

pub const requires_stage2 = true;

pub fn build(b: *std.Build) void {
    const test_step = b.step("test", "Test it");
    b.default_step = test_step;

    add(b, test_step, .Debug);
    add(b, test_step, .ReleaseFast);
    add(b, test_step, .ReleaseSmall);
    add(b, test_step, .ReleaseSafe);
}

fn add(b: *std.Build, test_step: *std.Build.Step, optimize: std.builtin.OptimizeMode) void {
    const lib = b.addExecutable(.{
        .name = "lib",
        .root_source_file = b.path("lib.zig"),
        .target = b.resolveTargetQuery(.{ .cpu_arch = .wasm32, .os_tag = .freestanding }),
        .optimize = optimize,
        .strip = false,
    });
    lib.entry = .disabled;
    lib.use_llvm = false;
    lib.use_lld = false;
    b.installArtifact(lib);

    const version_fmt = "version " ++ builtin.zig_version_string;

    const check_lib = lib.checkObject();
    check_lib.checkInHeaders();
    check_lib.checkExact("name producers");
    check_lib.checkExact("fields 2");
    check_lib.checkExact("field_name language");
    check_lib.checkExact("values 1");
    check_lib.checkExact("value_name Zig");
    check_lib.checkExact(version_fmt);
    check_lib.checkExact("field_name processed-by");
    check_lib.checkExact("values 1");
    check_lib.checkExact("value_name Zig");
    check_lib.checkExact(version_fmt);

    test_step.dependOn(&check_lib.step);
}

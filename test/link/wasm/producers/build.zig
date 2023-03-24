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
    const lib = b.addSharedLibrary(.{
        .name = "lib",
        .root_source_file = .{ .path = "lib.zig" },
        .target = .{ .cpu_arch = .wasm32, .os_tag = .freestanding },
        .optimize = optimize,
    });
    lib.use_llvm = false;
    lib.use_lld = false;
    lib.strip = false;
    lib.install();

    const version_fmt = "version " ++ builtin.zig_version_string;

    const check_lib = lib.checkObject();
    check_lib.checkStart("name producers");
    check_lib.checkNext("fields 2");
    check_lib.checkNext("field_name language");
    check_lib.checkNext("values 1");
    check_lib.checkNext("value_name Zig");
    check_lib.checkNext(version_fmt);
    check_lib.checkNext("field_name processed-by");
    check_lib.checkNext("values 1");
    check_lib.checkNext("value_name Zig");
    check_lib.checkNext(version_fmt);

    test_step.dependOn(&check_lib.step);
}

const std = @import("std");

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
    const no_export = b.addSharedLibrary(.{
        .name = "no-export",
        .root_source_file = .{ .path = "main.zig" },
        .optimize = optimize,
        .target = .{ .cpu_arch = .wasm32, .os_tag = .freestanding },
    });
    no_export.use_llvm = false;
    no_export.use_lld = false;

    const dynamic_export = b.addSharedLibrary(.{
        .name = "dynamic",
        .root_source_file = .{ .path = "main.zig" },
        .optimize = optimize,
        .target = .{ .cpu_arch = .wasm32, .os_tag = .freestanding },
    });
    dynamic_export.rdynamic = true;
    dynamic_export.use_llvm = false;
    dynamic_export.use_lld = false;

    const force_export = b.addSharedLibrary(.{
        .name = "force",
        .root_source_file = .{ .path = "main.zig" },
        .optimize = optimize,
        .target = .{ .cpu_arch = .wasm32, .os_tag = .freestanding },
    });
    force_export.export_symbol_names = &.{"foo"};
    force_export.use_llvm = false;
    force_export.use_lld = false;

    const check_no_export = no_export.checkObject();
    check_no_export.checkStart("Section export");
    check_no_export.checkNext("entries 1");
    check_no_export.checkNext("name memory");
    check_no_export.checkNext("kind memory");

    const check_dynamic_export = dynamic_export.checkObject();
    check_dynamic_export.checkStart("Section export");
    check_dynamic_export.checkNext("entries 2");
    check_dynamic_export.checkNext("name foo");
    check_dynamic_export.checkNext("kind function");

    const check_force_export = force_export.checkObject();
    check_force_export.checkStart("Section export");
    check_force_export.checkNext("entries 2");
    check_force_export.checkNext("name foo");
    check_force_export.checkNext("kind function");

    test_step.dependOn(&check_no_export.step);
    test_step.dependOn(&check_dynamic_export.step);
    test_step.dependOn(&check_force_export.step);
}

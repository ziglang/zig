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
    const main_mod = b.createModule(.{
        .root_source_file = b.path("main.zig"),
        .target = b.resolveTargetQuery(.{ .cpu_arch = .wasm32, .os_tag = .freestanding }),
        .optimize = optimize,
    });

    const no_export = b.addExecutable2(.{
        .name = "no-export",
        .root_module = main_mod,
        .use_llvm = false,
        .use_lld = false,
    });
    no_export.entry = .disabled;

    const dynamic_export = b.addExecutable2(.{
        .name = "dynamic",
        .root_module = main_mod,
        .use_llvm = false,
        .use_lld = false,
    });
    dynamic_export.entry = .disabled;
    dynamic_export.rdynamic = true;

    const force_export_mod = b.createModule(.{
        .root_source_file = b.path("main.zig"),
        .target = b.resolveTargetQuery(.{ .cpu_arch = .wasm32, .os_tag = .freestanding }),
        .optimize = optimize,
    });
    force_export_mod.export_symbol_names = &.{"foo"};

    const force_export = b.addExecutable2(.{
        .name = "force",
        .root_module = force_export_mod,
        .use_llvm = false,
        .use_lld = false,
    });
    force_export.entry = .disabled;

    const check_no_export = no_export.checkObject();
    check_no_export.checkInHeaders();
    check_no_export.checkExact("Section export");
    check_no_export.checkExact("entries 1");
    check_no_export.checkExact("name memory");
    check_no_export.checkExact("kind memory");

    const check_dynamic_export = dynamic_export.checkObject();
    check_dynamic_export.checkInHeaders();
    check_dynamic_export.checkExact("Section export");
    check_dynamic_export.checkExact("entries 2");
    check_dynamic_export.checkExact("name foo");
    check_dynamic_export.checkExact("kind function");

    const check_force_export = force_export.checkObject();
    check_force_export.checkInHeaders();
    check_force_export.checkExact("Section export");
    check_force_export.checkExact("entries 2");
    check_force_export.checkExact("name foo");
    check_force_export.checkExact("kind function");

    test_step.dependOn(&check_no_export.step);
    test_step.dependOn(&check_dynamic_export.step);
    test_step.dependOn(&check_force_export.step);
}

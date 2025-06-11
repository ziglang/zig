const std = @import("std");

pub fn build(b: *std.Build) void {
    const test_step = b.step("test", "Test it");
    b.default_step = test_step;

    // Ensure ldexp symbols are available in Release modes
    // Regression test for https://github.com/ziglang/zig/issues/23358
    add(b, test_step, .ReleaseSafe);
    add(b, test_step, .ReleaseFast);
    add(b, test_step, .ReleaseSmall);
    // Also verify Debug still works
    add(b, test_step, .Debug);
}

fn add(b: *std.Build, test_step: *std.Build.Step, optimize: std.builtin.OptimizeMode) void {
    const exe = b.addExecutable(.{
        .name = "ldexp_test",
        .root_module = b.createModule(.{
            .root_source_file = b.path("lib.zig"),
            .target = b.resolveTargetQuery(.{ .cpu_arch = .wasm32, .os_tag = .freestanding }),
            .optimize = optimize,
        }),
    });

    exe.entry = .disabled;
    exe.rdynamic = true;

    exe.root_module.export_symbol_names = &.{ "use_double", "use_float", "use_long" };

    b.installArtifact(exe);

    test_step.dependOn(&exe.step);
}

const std = @import("std");
const builtin = @import("builtin");

pub fn build(b: *std.Build) void {
    const test_step = b.step("test", "Test it");
    b.default_step = test_step;

    add(b, test_step, "test_c_Debug", "test_cpp_Debug", .Debug);
    add(b, test_step, "test_c_ReleaseFast", "test_cpp_ReleaseFast", .ReleaseFast);
    add(b, test_step, "test_c_ReleaseSmall", "test_cpp_ReleaseSmall", .ReleaseSmall);
    add(b, test_step, "test_c_ReleaseSafe", "test_cpp_ReleaseSafe", .ReleaseSafe);
}

fn add(
    b: *std.Build,
    test_step: *std.Build.Step,
    c_name: []const u8,
    cpp_name: []const u8,
    optimize: std.builtin.OptimizeMode,
) void {
    const target = b.graph.host;

    const c_mod = b.createModule(.{
        .optimize = optimize,
        .target = target,
    });
    c_mod.addCSourceFile(.{ .file = b.path("test.c"), .flags = &[0][]const u8{} });
    c_mod.link_libc = true;

    const exe_c = b.addExecutable(.{ .name = c_name, .root_module = c_mod });

    const cpp_mod = b.createModule(.{
        .optimize = optimize,
        .target = target,
    });
    cpp_mod.addCSourceFile(.{ .file = b.path("test.cpp"), .flags = &[0][]const u8{} });
    cpp_mod.link_libcpp = true;

    const exe_cpp = b.addExecutable(.{ .name = cpp_name, .root_module = cpp_mod });

    b.default_step.dependOn(&exe_cpp.step);

    switch (target.result.os.tag) {
        .windows => {
            // https://github.com/ziglang/zig/issues/8531
            exe_cpp.want_lto = false;
        },
        .macos => {
            // https://github.com/ziglang/zig/issues/8680
            exe_cpp.want_lto = false;
            exe_c.want_lto = false;
        },
        else => {},
    }

    const run_c_cmd = b.addRunArtifact(exe_c);
    run_c_cmd.expectExitCode(0);
    run_c_cmd.skip_foreign_checks = true;
    test_step.dependOn(&run_c_cmd.step);

    const run_cpp_cmd = b.addRunArtifact(exe_cpp);
    run_cpp_cmd.expectExitCode(0);
    run_cpp_cmd.skip_foreign_checks = true;
    test_step.dependOn(&run_cpp_cmd.step);
}

const std = @import("std");

pub fn build(b: *std.Build) void {
    const test_step = b.step("test", "Test it");
    b.default_step = test_step;

    const target = b.standardTargetOptions(.{});

    add(b, test_step, target, .Debug);
    add(b, test_step, target, .ReleaseFast);
    add(b, test_step, target, .ReleaseSmall);
    add(b, test_step, target, .ReleaseSafe);
}

fn add(b: *std.Build, test_step: *std.Build.Step, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) void {
    const lib = b.addStaticLibrary(.{
        .name = "test",
        .root_source_file = b.path("test.zig"),
        .target = target,
        .optimize = optimize,
    });

    const options = b.addOptions();
    const exe = b.addExecutable(.{
        .name = "test",
        .root_source_file = b.path("main.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addOptions("build_options", options);

    exe.addCSourceFile(.{ .file = b.path("test.c"), .flags = &[_][]const u8{"-std=c11"} });
    exe.addCSourceFile(.{ .file = b.path("test.c++"), .flags = &[_][]const u8{ "-fno-exceptions", "-fno-rtti" } });

    exe.addCSourceFile(.{ .file = b.path("test.m") });

    var with_asm = false;
    if (target.result.os.tag == .linux) {
        switch (target.result.cpu.arch) {
            .x86_64 => {
                exe.addAssemblyFile(.{ .file = b.path("test_x86_64.s") });
                with_asm = true;
            },
            .aarch64 => {
                exe.addAssemblyFile(.{ .file = b.path("test_aarch64.s") });
                with_asm = true;
            },
            else => {},
        }
    }
    options.addOption(bool, "with_asm", with_asm);

    const with_asm_prep = switch (target.result.cpu.arch) {
        .x86_64, .x86, .aarch64, .arm, .riscv64 => true,
        else => false,
    };
    if (with_asm_prep) exe.addAssemblyFile(.{ .file = b.path("test.S"), .lang = .assembly_with_cpp, .flags = &[_][]const u8{"-DNO_ERROR"} });
    options.addOption(bool, "with_asm_prep", with_asm_prep);

    exe.addCSourceFile(.{ .file = b.path("test.h"), .lang = .cpp, .flags = &[_][]const u8{"-DIMPLEMENTATION"} });

    exe.linkLibrary(lib);
    //exe.linkLibC();

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.skip_foreign_checks = true;
    run_cmd.expectExitCode(0);

    test_step.dependOn(&run_cmd.step);
}

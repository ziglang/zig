const std = @import("std");

pub const requires_symlinks = true;

pub fn build(b: *std.Build) void {
    const test_step = b.step("test", "Test it");
    b.default_step = test_step;

    add(b, test_step, .Debug);
    add(b, test_step, .ReleaseFast);
    add(b, test_step, .ReleaseSmall);
    add(b, test_step, .ReleaseSafe);
}

fn add(b: *std.Build, test_step: *std.Build.Step, optimize: std.builtin.OptimizeMode) void {
    const target: std.zig.CrossTarget = .{ .os_tag = .macos };

    const dylib_mod = b.createModule(.{
        .c_source_files = .{
            .files = &.{"a.c"},
            .flags = &.{},
        },
    });
    const dylib = b.addSharedLibrary(.{
        .name = "a",
        .main_module = dylib_mod,
        .version = .{ .major = 1, .minor = 0 },
        .optimize = optimize,
        .target = target,
    });
    dylib.linkLibC();

    // -dead_strip_dylibs
    // -needed-la
    const exe_mod = b.createModule(.{
        .c_source_files = .{
            .files = &.{"main.c"},
            .flags = &.{},
        },
    });
    const exe = b.addExecutable(.{
        .name = "test",
        .main_module = exe_mod,
        .optimize = optimize,
        .target = target,
    });
    exe.linkLibC();
    exe.linkSystemLibraryNeeded("a");
    exe.addLibraryPathDirectorySource(dylib.getOutputDirectorySource());
    exe.addRPathDirectorySource(dylib.getOutputDirectorySource());
    exe.dead_strip_dylibs = true;

    const check = exe.checkObject();
    check.checkStart("cmd LOAD_DYLIB");
    check.checkNext("name @rpath/liba.dylib");

    const run_cmd = check.runAndCompare();
    run_cmd.expectStdOutEqual("");
    test_step.dependOn(&run_cmd.step);
}

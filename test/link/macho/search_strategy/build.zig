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

    {
        // -search_dylibs_first
        const exe = createScenario(b, optimize, target, "search_dylibs_first");
        exe.search_strategy = .dylibs_first;

        const check = exe.checkObject();
        check.checkStart("cmd LOAD_DYLIB");
        check.checkNext("name @rpath/libsearch_dylibs_first.dylib");

        const run = check.runAndCompare();
        run.expectStdOutEqual("Hello world");
        test_step.dependOn(&run.step);
    }

    {
        // -search_paths_first
        const exe = createScenario(b, optimize, target, "search_paths_first");
        exe.search_strategy = .paths_first;

        const run = b.addRunArtifact(exe);
        run.skip_foreign_checks = true;
        run.expectStdOutEqual("Hello world");
        test_step.dependOn(&run.step);
    }
}

fn createScenario(
    b: *std.Build,
    optimize: std.builtin.OptimizeMode,
    target: std.zig.CrossTarget,
    name: []const u8,
) *std.Build.Step.Compile {
    const static = b.addStaticLibrary(.{
        .name = name,
        .optimize = optimize,
        .target = target,
    });
    static.addCSourceFile("a.c", &.{});
    static.linkLibC();
    static.override_dest_dir = std.Build.InstallDir{
        .custom = "static",
    };

    const dylib = b.addSharedLibrary(.{
        .name = name,
        .version = .{ .major = 1, .minor = 0 },
        .optimize = optimize,
        .target = target,
    });
    dylib.addCSourceFile("a.c", &.{});
    dylib.linkLibC();
    dylib.override_dest_dir = std.Build.InstallDir{
        .custom = "dynamic",
    };

    const exe = b.addExecutable(.{
        .name = name,
        .optimize = optimize,
        .target = target,
    });
    exe.addCSourceFile("main.c", &.{});
    exe.linkSystemLibraryName(name);
    exe.linkLibC();
    exe.addLibraryPathDirectorySource(static.getOutputDirectorySource());
    exe.addLibraryPathDirectorySource(dylib.getOutputDirectorySource());
    exe.addRPathDirectorySource(dylib.getOutputDirectorySource());
    return exe;
}

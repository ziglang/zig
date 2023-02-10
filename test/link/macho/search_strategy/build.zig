const std = @import("std");

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});
    const target: std.zig.CrossTarget = .{ .os_tag = .macos };

    const test_step = b.step("test", "Test");
    test_step.dependOn(b.getInstallStep());

    {
        // -search_dylibs_first
        const exe = createScenario(b, optimize, target);
        exe.search_strategy = .dylibs_first;

        const check = exe.checkObject(.macho);
        check.checkStart("cmd LOAD_DYLIB");
        check.checkNext("name @rpath/liba.dylib");

        const run = check.runAndCompare();
        run.cwd = b.pathFromRoot(".");
        run.expectStdOutEqual("Hello world");
        test_step.dependOn(&run.step);
    }

    {
        // -search_paths_first
        const exe = createScenario(b, optimize, target);
        exe.search_strategy = .paths_first;

        const run = std.Build.EmulatableRunStep.create(b, "run", exe);
        run.cwd = b.pathFromRoot(".");
        run.expectStdOutEqual("Hello world");
        test_step.dependOn(&run.step);
    }
}

fn createScenario(
    b: *std.Build,
    optimize: std.builtin.OptimizeMode,
    target: std.zig.CrossTarget,
) *std.Build.CompileStep {
    const static = b.addStaticLibrary(.{
        .name = "a",
        .optimize = optimize,
        .target = target,
    });
    static.addCSourceFile("a.c", &.{});
    static.linkLibC();
    static.override_dest_dir = std.Build.InstallDir{
        .custom = "static",
    };
    static.install();

    const dylib = b.addSharedLibrary(.{
        .name = "a",
        .version = .{ .major = 1, .minor = 0 },
        .optimize = optimize,
        .target = target,
    });
    dylib.addCSourceFile("a.c", &.{});
    dylib.linkLibC();
    dylib.override_dest_dir = std.Build.InstallDir{
        .custom = "dynamic",
    };
    dylib.install();

    const exe = b.addExecutable(.{
        .name = "main",
        .optimize = optimize,
        .target = target,
    });
    exe.addCSourceFile("main.c", &.{});
    exe.linkSystemLibraryName("a");
    exe.linkLibC();
    exe.addLibraryPath(b.pathFromRoot("zig-out/static"));
    exe.addLibraryPath(b.pathFromRoot("zig-out/dynamic"));
    exe.addRPath(b.pathFromRoot("zig-out/dynamic"));
    return exe;
}

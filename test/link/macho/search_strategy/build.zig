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
        const exe = createScenario(b, optimize, target, "search_dylibs_first", .mode_first);

        const check = exe.checkObject();
        check.checkStart();
        check.checkExact("cmd LOAD_DYLIB");
        check.checkExact("name @rpath/libsearch_dylibs_first.dylib");
        test_step.dependOn(&check.step);

        const run = b.addRunArtifact(exe);
        run.skip_foreign_checks = true;
        run.expectStdOutEqual("Hello world");
        test_step.dependOn(&run.step);
    }

    {
        // -search_paths_first
        const exe = createScenario(b, optimize, target, "search_paths_first", .paths_first);

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
    search_strategy: std.Build.Step.Compile.SystemLib.SearchStrategy,
) *std.Build.Step.Compile {
    const static = b.addStaticLibrary(.{
        .name = name,
        .optimize = optimize,
        .target = target,
    });
    static.addCSourceFile(.{ .file = .{ .path = "a.c" }, .flags = &.{} });
    static.linkLibC();

    const dylib = b.addSharedLibrary(.{
        .name = name,
        .version = .{ .major = 1, .minor = 0, .patch = 0 },
        .optimize = optimize,
        .target = target,
    });
    dylib.addCSourceFile(.{ .file = .{ .path = "a.c" }, .flags = &.{} });
    dylib.linkLibC();

    const exe = b.addExecutable(.{
        .name = name,
        .optimize = optimize,
        .target = target,
    });
    exe.addCSourceFile(.{ .file = .{ .path = "main.c" }, .flags = &.{} });
    exe.linkSystemLibrary2(name, .{
        .use_pkg_config = .no,
        .search_strategy = search_strategy,
    });
    exe.linkLibC();
    exe.addLibraryPath(static.getEmittedBinDirectory());
    exe.addLibraryPath(dylib.getEmittedBinDirectory());
    exe.addRPath(dylib.getEmittedBinDirectory());
    return exe;
}

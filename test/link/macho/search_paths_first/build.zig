const std = @import("std");
const Builder = std.build.Builder;

pub fn build(b: *Builder) void {
    const mode = b.standardReleaseOptions();

    const test_step = b.step("test", "Test");
    test_step.dependOn(b.getInstallStep());

    const static = b.addStaticLibrary("a", null);
    static.setBuildMode(mode);
    static.addCSourceFile("a.c", &.{});
    static.linkLibC();
    static.override_dest_dir = std.build.InstallDir{
        .custom = "static",
    };
    static.install();

    const dylib = b.addSharedLibrary("a", null, b.version(1, 0, 0));
    dylib.setBuildMode(mode);
    dylib.addCSourceFile("a.c", &.{});
    dylib.linkLibC();
    dylib.override_dest_dir = std.build.InstallDir{
        .custom = "dynamic",
    };
    dylib.install();

    const exe = b.addExecutable("main", null);
    exe.setBuildMode(mode);
    exe.addCSourceFile("main.c", &.{});
    exe.linkSystemLibraryName("a");
    exe.linkLibC();
    exe.addLibraryPath(b.pathFromRoot("zig-out/static"));
    exe.addLibraryPath(b.pathFromRoot("zig-out/dynamic"));
    exe.search_strategy = .paths_first;

    const run = exe.run();
    run.cwd = b.pathFromRoot(".");
    run.expectStdOutEqual("Hello world");
    test_step.dependOn(&run.step);
}

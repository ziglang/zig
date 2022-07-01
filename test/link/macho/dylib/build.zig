const std = @import("std");
const Builder = std.build.Builder;

pub fn build(b: *Builder) void {
    const mode = b.standardReleaseOptions();

    const test_step = b.step("test", "Test");
    test_step.dependOn(b.getInstallStep());

    const dylib = b.addSharedLibrary("a", null, b.version(1, 0, 0));
    dylib.setBuildMode(mode);
    dylib.addCSourceFile("a.c", &.{});
    dylib.linkLibC();
    dylib.install();

    const check_dylib = dylib.checkObject(.macho);
    check_dylib.checkStart("cmd ID_DYLIB");
    check_dylib.checkNext("name @rpath/liba.dylib");
    check_dylib.checkNext("timestamp 2");
    check_dylib.checkNext("current version 10000");
    check_dylib.checkNext("compatibility version 10000");

    test_step.dependOn(&check_dylib.step);

    const exe = b.addExecutable("main", null);
    exe.setBuildMode(mode);
    exe.addCSourceFile("main.c", &.{});
    exe.linkSystemLibrary("a");
    exe.linkLibC();
    exe.addLibraryPath(b.pathFromRoot("zig-out/lib/"));
    exe.addRPath(b.pathFromRoot("zig-out/lib"));

    const check_exe = exe.checkObject(.macho);
    check_exe.checkStart("cmd LOAD_DYLIB");
    check_exe.checkNext("name @rpath/liba.dylib");
    check_exe.checkNext("timestamp 2");
    check_exe.checkNext("current version 10000");
    check_exe.checkNext("compatibility version 10000");

    check_exe.checkStart("cmd RPATH");
    check_exe.checkNext(std.fmt.allocPrint(b.allocator, "path {s}", .{b.pathFromRoot("zig-out/lib")}) catch unreachable);

    test_step.dependOn(&check_exe.step);

    const run = exe.run();
    run.cwd = b.pathFromRoot(".");
    run.expectStdOutEqual("Hello world");
    test_step.dependOn(&run.step);
}

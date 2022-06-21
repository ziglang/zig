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

    {
        const check_macho = dylib.checkMachO();
        check_macho.checkLoadCommand(.{
            .cmd = std.macho.LC.ID_DYLIB,
            .name = "@rpath/liba.dylib",
            .timestamp = 2,
            .current_version = 0x10000,
            .compat_version = 0x10000,
        });
        test_step.dependOn(&check_macho.step);
    }

    const exe = b.addExecutable("main", null);
    exe.setBuildMode(mode);
    exe.addCSourceFile("main.c", &.{});
    exe.linkSystemLibrary("a");
    exe.linkLibC();
    exe.addLibraryPath(b.pathFromRoot("zig-out/lib/"));
    exe.addRPath(b.pathFromRoot("zig-out/lib"));

    {
        const check_macho = exe.checkMachO();
        check_macho.checkLoadCommand(.{
            .cmd = std.macho.LC.LOAD_DYLIB,
            .name = "@rpath/liba.dylib",
            .timestamp = 2,
            .current_version = 0x10000,
            .compat_version = 0x10000,
        });
        test_step.dependOn(&check_macho.step);
    }
    {
        const check_macho = exe.checkMachO();
        check_macho.checkLoadCommand(.{
            .cmd = std.macho.LC.RPATH,
            .name = b.pathFromRoot("zig-out/lib"),
        });
        test_step.dependOn(&check_macho.step);
    }

    const run = exe.run();
    run.cwd = b.pathFromRoot(".");
    run.expectStdOutEqual("Hello world");
    test_step.dependOn(&run.step);
}

const std = @import("std");
const Builder = std.build.Builder;

pub fn build(b: *Builder) void {
    const mode = b.standardReleaseOptions();

    const test_step = b.step("test", "Test");

    const dylib = b.addSharedLibrary("a", null, b.version(1, 0, 0));
    dylib.setBuildMode(mode);
    dylib.addCSourceFile("a.c", &.{});
    dylib.linkLibC();
    dylib.install();

    const exe = b.addExecutable("main", null);
    exe.setBuildMode(mode);
    exe.addCSourceFile("main.c", &.{});
    exe.linkSystemLibrary("a");
    exe.linkLibC();
    exe.addLibraryPath(b.pathFromRoot("zig-out/lib/"));
    exe.addRPath(b.pathFromRoot("zig-out/lib"));

    const run = exe.run();
    run.cwd = b.pathFromRoot(".");
    run.expectStdOutEqual("Hello world");

    const exp_dylib = std.macho.createLoadDylibCommand(b.allocator, "@rpath/liba.dylib", 2, 0x10000, 0x10000) catch unreachable;
    var buf = std.ArrayList(u8).init(b.allocator);
    defer buf.deinit();
    exp_dylib.write(buf.writer()) catch unreachable;
    const check_file = std.build.CheckFileStep.create(b, exe.getOutputSource(), &[_][]const u8{buf.items});

    test_step.dependOn(b.getInstallStep());
    test_step.dependOn(&run.step);
    test_step.dependOn(&check_file.step);
}

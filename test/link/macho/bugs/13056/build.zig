const std = @import("std");

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});

    const target: std.zig.CrossTarget = .{ .os_tag = .macos };
    const target_info = std.zig.system.NativeTargetInfo.detect(target) catch unreachable;
    const sdk = std.zig.system.darwin.getDarwinSDK(b.allocator, target_info.target) orelse
        @panic("macOS SDK is required to run the test");

    const test_step = b.step("test", "Test the program");

    const exe = b.addExecutable(.{
        .name = "test",
        .optimize = optimize,
    });
    b.default_step.dependOn(&exe.step);
    exe.addIncludePath(std.fs.path.join(b.allocator, &.{ sdk.path, "/usr/include" }) catch unreachable);
    exe.addIncludePath(std.fs.path.join(b.allocator, &.{ sdk.path, "/usr/include/c++/v1" }) catch unreachable);
    exe.addCSourceFile("test.cpp", &.{
        "-nostdlib++",
        "-nostdinc++",
    });
    exe.addObjectFile(std.fs.path.join(b.allocator, &.{ sdk.path, "/usr/lib/libc++.tbd" }) catch unreachable);

    const run_cmd = exe.run();
    run_cmd.expectStdErrEqual("x: 5\n");

    test_step.dependOn(&run_cmd.step);
}

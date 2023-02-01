const std = @import("std");

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});
    const target = std.zig.CrossTarget{ .os_tag = .macos };

    const test_step = b.step("test", "Test");
    test_step.dependOn(b.getInstallStep());

    const obj = b.addObject(.{
        .name = "test",
        .root_source_file = .{ .path = "main.zig" },
        .optimize = optimize,
        .target = target,
    });

    const check = obj.checkObject(.macho);

    check.checkInSymtab();
    check.checkNext("{*} (__DATA,__TestGlobal) external _test_global");

    check.checkInSymtab();
    check.checkNext("{*} (__TEXT,__TestFn) external _testFn");

    if (optimize == .Debug) {
        check.checkInSymtab();
        check.checkNext("{*} (__TEXT,__TestGenFnA) _main.testGenericFn__anon_{*}");
    }

    test_step.dependOn(&check.step);
}

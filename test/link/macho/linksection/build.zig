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
    const target = std.zig.CrossTarget{ .os_tag = .macos };

    const obj = b.addObject(.{
        .name = "test",
        .root_source_file = .{ .path = "main.zig" },
        .optimize = optimize,
        .target = target,
    });

    const check = obj.checkObject();

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

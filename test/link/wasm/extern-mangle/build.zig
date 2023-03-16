const std = @import("std");

pub fn build(b: *std.Build) void {
    const test_step = b.step("test", "Test it");
    b.default_step = test_step;

    add(b, test_step, .Debug);
    add(b, test_step, .ReleaseFast);
    add(b, test_step, .ReleaseSmall);
    add(b, test_step, .ReleaseSafe);
}

fn add(b: *std.Build, test_step: *std.Build.Step, optimize: std.builtin.OptimizeMode) void {
    const lib = b.addSharedLibrary(.{
        .name = "lib",
        .root_source_file = .{ .path = "lib.zig" },
        .target = .{ .cpu_arch = .wasm32, .os_tag = .freestanding },
        .optimize = optimize,
    });
    lib.import_symbols = true; // import `a` and `b`
    lib.rdynamic = true; // export `foo`

    const check_lib = lib.checkObject();
    check_lib.checkStart("Section import");
    check_lib.checkNext("entries 2"); // a.hello & b.hello
    check_lib.checkNext("module a");
    check_lib.checkNext("name hello");
    check_lib.checkNext("module b");
    check_lib.checkNext("name hello");

    test_step.dependOn(&check_lib.step);
}

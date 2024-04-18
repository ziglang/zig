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
    const lib = b.addExecutable(.{
        .name = "lib",
        .root_source_file = b.path("lib.zig"),
        .target = b.resolveTargetQuery(.{ .cpu_arch = .wasm32, .os_tag = .freestanding }),
        .optimize = optimize,
    });
    lib.entry = .disabled;
    lib.import_symbols = true; // import `a` and `b`
    lib.rdynamic = true; // export `foo`

    const check_lib = lib.checkObject();
    check_lib.checkInHeaders();
    check_lib.checkExact("Section import");
    check_lib.checkExact("entries 2"); // a.hello & b.hello
    check_lib.checkExact("module a");
    check_lib.checkExact("name hello");
    check_lib.checkExact("module b");
    check_lib.checkExact("name hello");

    test_step.dependOn(&check_lib.step);
}

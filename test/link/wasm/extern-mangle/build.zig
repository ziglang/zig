const std = @import("std");
const Builder = std.build.Builder;

pub fn build(b: *Builder) void {
    const test_step = b.step("test", "Test");
    test_step.dependOn(b.getInstallStep());

    const lib = b.addSharedLibrary(.{
        .name = "lib",
        .root_source_file = .{ .path = "lib.zig" },
        .target = .{ .cpu_arch = .wasm32, .os_tag = .freestanding },
        .optimize = b.standardOptimizeOption(.{}),
    });
    lib.import_symbols = true; // import `a` and `b`
    lib.rdynamic = true; // export `foo`
    lib.install();

    const check_lib = lib.checkObject(.wasm);
    check_lib.checkStart("Section import");
    check_lib.checkNext("entries 2"); // a.hello & b.hello
    check_lib.checkNext("module a");
    check_lib.checkNext("name hello");
    check_lib.checkNext("module b");
    check_lib.checkNext("name hello");

    test_step.dependOn(&check_lib.step);
}

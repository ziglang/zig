const std = @import("std");
const Builder = std.build.Builder;

pub fn build(b: *Builder) void {
    const mode = b.standardReleaseOptions();

    const test_step = b.step("test", "Test");
    test_step.dependOn(b.getInstallStep());

    // The code in question will pull-in compiler-rt,
    // and therefore link with its archive file.
    const lib = b.addSharedLibrary("main", "main.zig", .unversioned);
    lib.setBuildMode(mode);
    lib.setTarget(.{ .cpu_arch = .wasm32, .os_tag = .freestanding });
    lib.use_llvm = false;
    lib.use_stage1 = false;
    lib.use_lld = false;
    lib.strip = false;

    const check = lib.checkObject(.wasm);
    check.checkStart("Section import");
    check.checkNext("entries 1"); // __truncsfhf2 should have been resolved, so only 1 import (compiler-rt's memcpy).

    check.checkStart("Section custom");
    check.checkNext("name __truncsfhf2"); // Ensure it was imported and resolved

    test_step.dependOn(&check.step);
}

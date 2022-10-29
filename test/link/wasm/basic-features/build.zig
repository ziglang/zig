const std = @import("std");

pub fn build(b: *std.build.Builder) void {
    const mode = b.standardReleaseOptions();

    // Library with explicitly set cpu features
    const lib = b.addSharedLibrary("lib", "main.zig", .unversioned);
    lib.setTarget(.{ .cpu_arch = .wasm32, .os_tag = .freestanding });
    lib.target.cpu_model = .{ .explicit = &std.Target.wasm.cpu.mvp };
    lib.target.cpu_features_add.addFeature(0); // index 0 == atomics (see std.Target.wasm.Features)
    lib.setBuildMode(mode);
    lib.use_llvm = false;
    lib.use_lld = false;

    // Verify the result contains the features explicitly set on the target for the library.
    const check = lib.checkObject(.wasm);
    check.checkStart("name target_features");
    check.checkNext("features 1");
    check.checkNext("+ atomics");

    const test_step = b.step("test", "Run linker test");
    test_step.dependOn(&check.step);
}

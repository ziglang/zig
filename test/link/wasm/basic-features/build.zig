const std = @import("std");

pub const requires_stage2 = true;

pub fn build(b: *std.Build) void {
    // Library with explicitly set cpu features
    const lib = b.addExecutable(.{
        .name = "lib",
        .root_source_file = b.path("main.zig"),
        .optimize = .Debug,
        .target = b.resolveTargetQuery(.{
            .cpu_arch = .wasm32,
            .cpu_model = .{ .explicit = &std.Target.wasm.cpu.mvp },
            .cpu_features_add = std.Target.wasm.featureSet(&.{.atomics}),
            .os_tag = .freestanding,
        }),
    });
    lib.entry = .disabled;
    lib.use_llvm = false;
    lib.use_lld = false;

    // Verify the result contains the features explicitly set on the target for the library.
    const check = lib.checkObject();
    check.checkInHeaders();
    check.checkExact("name target_features");
    check.checkExact("features 1");
    check.checkExact("+ atomics");

    const test_step = b.step("test", "Run linker test");
    test_step.dependOn(&check.step);
    b.default_step = test_step;
}

const std = @import("std");

pub const requires_stage2 = true;

pub fn build(b: *std.Build) void {
    // Wasm Object file which we will use to infer the features from
    const c_obj = b.addObject(.{
        .name = "c_obj",
        .optimize = .Debug,
        .target = b.resolveTargetQuery(.{
            .cpu_arch = .wasm32,
            .cpu_model = .{ .explicit = &std.Target.wasm.cpu.bleeding_edge },
            .os_tag = .freestanding,
        }),
    });
    c_obj.addCSourceFile(.{ .file = b.path("foo.c"), .flags = &.{} });

    // Wasm library that doesn't have any features specified. This will
    // infer its featureset from other linked object files.
    const lib = b.addExecutable(.{
        .name = "lib",
        .root_source_file = b.path("main.zig"),
        .optimize = .Debug,
        .target = b.resolveTargetQuery(.{
            .cpu_arch = .wasm32,
            .cpu_model = .{ .explicit = &std.Target.wasm.cpu.mvp },
            .os_tag = .freestanding,
        }),
    });
    lib.entry = .disabled;
    lib.use_llvm = false;
    lib.use_lld = false;
    lib.addObject(c_obj);

    // Verify the result contains the features from the C Object file.
    const check = lib.checkObject();
    check.checkInHeaders();
    check.checkExact("name target_features");
    check.checkExact("features 7");
    check.checkExact("+ atomics");
    check.checkExact("+ bulk-memory");
    check.checkExact("+ mutable-globals");
    check.checkExact("+ nontrapping-fptoint");
    check.checkExact("+ sign-ext");
    check.checkExact("+ simd128");
    check.checkExact("+ tail-call");

    const test_step = b.step("test", "Run linker test");
    test_step.dependOn(&check.step);
    b.default_step = test_step;
}

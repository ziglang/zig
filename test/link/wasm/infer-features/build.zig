const std = @import("std");

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});

    // Wasm Object file which we will use to infer the features from
    const c_obj = b.addObject(.{
        .name = "c_obj",
        .optimize = optimize,
        .target = .{
            .cpu_arch = .wasm32,
            .cpu_model = .{ .explicit = &std.Target.wasm.cpu.bleeding_edge },
            .os_tag = .freestanding,
        },
    });
    c_obj.addCSourceFile("foo.c", &.{});

    // Wasm library that doesn't have any features specified. This will
    // infer its featureset from other linked object files.
    const lib = b.addSharedLibrary(.{
        .name = "lib",
        .root_source_file = .{ .path = "main.zig" },
        .optimize = optimize,
        .target = .{
            .cpu_arch = .wasm32,
            .cpu_model = .{ .explicit = &std.Target.wasm.cpu.mvp },
            .os_tag = .freestanding,
        },
    });
    lib.use_llvm = false;
    lib.use_lld = false;
    lib.addObject(c_obj);

    // Verify the result contains the features from the C Object file.
    const check = lib.checkObject(.wasm);
    check.checkStart("name target_features");
    check.checkNext("features 7");
    check.checkNext("+ atomics");
    check.checkNext("+ bulk-memory");
    check.checkNext("+ mutable-globals");
    check.checkNext("+ nontrapping-fptoint");
    check.checkNext("+ sign-ext");
    check.checkNext("+ simd128");
    check.checkNext("+ tail-call");

    const test_step = b.step("test", "Run linker test");
    test_step.dependOn(&check.step);
}

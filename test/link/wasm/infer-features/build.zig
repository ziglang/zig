const std = @import("std");

pub const requires_stage2 = true;

pub fn build(b: *std.Build) void {
    // Wasm Object file which we will use to infer the features from
    const c_mod = b.createModule(.{
        .root_source_file = null,
        .target = b.resolveTargetQuery(.{
            .cpu_arch = .wasm32,
            .cpu_model = .{ .explicit = &std.Target.wasm.cpu.bleeding_edge },
            .os_tag = .freestanding,
        }),
        .optimize = .Debug,
    });
    c_mod.addCSourceFile(.{ .file = b.path("foo.c") });

    const c_obj = b.addObject2(.{
        .name = "c_obj",
        .root_module = c_mod,
    });

    // Wasm library that doesn't have any features specified. This will
    // infer its featureset from other linked object files.
    const lib_mod = b.createModule(.{
        .root_source_file = b.path("main.zig"),
        .target = b.resolveTargetQuery(.{
            .cpu_arch = .wasm32,
            .cpu_model = .{ .explicit = &std.Target.wasm.cpu.mvp },
            .os_tag = .freestanding,
        }),
        .optimize = .Debug,
    });
    lib_mod.addObject(c_obj);

    const lib = b.addExecutable2(.{
        .name = "lib",
        .root_module = lib_mod,
        .use_llvm = false,
        .use_lld = false,
    });
    lib.entry = .disabled;

    // Verify the result contains the features from the C Object file.
    const check = lib.checkObject();
    check.checkInHeaders();
    check.checkExact("name target_features");
    check.checkExact("features 14");
    check.checkExact("+ atomics");
    check.checkExact("+ bulk-memory");
    check.checkExact("+ exception-handling");
    check.checkExact("+ extended-const");
    check.checkExact("+ half-precision");
    check.checkExact("+ multimemory");
    check.checkExact("+ multivalue");
    check.checkExact("+ mutable-globals");
    check.checkExact("+ nontrapping-fptoint");
    check.checkExact("+ reference-types");
    check.checkExact("+ relaxed-simd");
    check.checkExact("+ sign-ext");
    check.checkExact("+ simd128");
    check.checkExact("+ tail-call");

    const test_step = b.step("test", "Run linker test");
    test_step.dependOn(&check.step);
    b.default_step = test_step;
}

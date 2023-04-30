const std = @import("std");

pub const requires_stage2 = true;

pub fn build(b: *std.Build) void {
    // Wasm Object file which we will use to infer the features from
    const c_obj_mod = b.createModule(.{ .c_source_files = .{
        .files = &.{"foo.c"},
        .flags = &.{},
    } });

    const c_obj = b.addObject(.{
        .name = "c_obj",
        .main_module = c_obj_mod,
        .optimize = .Debug,
        .target = .{
            .cpu_arch = .wasm32,
            .cpu_model = .{ .explicit = &std.Target.wasm.cpu.bleeding_edge },
            .os_tag = .freestanding,
        },
    });

    // Wasm library that doesn't have any features specified. This will
    // infer its featureset from other linked object files.
    const mod = b.createModule(.{
        .source_file = .{ .path = "main.zig" },
    });
    const lib = b.addSharedLibrary(.{
        .name = "lib",
        .main_module = mod,
        .optimize = .Debug,
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
    const check = lib.checkObject();
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
    b.default_step = test_step;
}

const std = @import("std");
const Builder = std.build.Builder;
const CrossTarget = std.zig.CrossTarget;

pub fn build(b: *Builder) void {
    const mode = b.standardReleaseOptions();
    const target = b.standardTargetOptions(.{});

    const is_wine_enabled = b.option(bool, "enable-wine", "Use Wine to run cross compiled Windows tests") orelse false;
    const is_qemu_enabled = b.option(bool, "enable-qemu", "Use QEMU to run cross compiled foreign architecture tests") orelse false;
    const is_wasmtime_enabled = b.option(bool, "enable-wasmtime", "Use Wasmtime to enable and run WASI libstd tests") orelse false;
    const is_darling_enabled = b.option(bool, "enable-darling", "[Experimental] Use Darling to run cross compiled macOS tests") orelse false;
    const single_threaded = b.option(bool, "single-threaded", "Test single threaded mode") orelse false;
    b.enable_wine = is_wine_enabled;
    b.enable_qemu = is_qemu_enabled;
    b.enable_wasmtime = is_wasmtime_enabled;
    b.enable_darling = is_darling_enabled;

    const test_step = b.step("test", "Test the program");

    const exe_c = b.addExecutable("test_c", null);
    b.default_step.dependOn(&exe_c.step);
    exe_c.addCSourceFile("test.c", &[0][]const u8{});
    exe_c.setBuildMode(mode);
    exe_c.setTarget(target);
    exe_c.linkLibC();

    const exe_cpp = b.addExecutable("test_cpp", null);
    b.default_step.dependOn(&exe_cpp.step);
    exe_cpp.addCSourceFile("test.cpp", &[0][]const u8{});
    exe_cpp.setBuildMode(mode);
    exe_cpp.setTarget(target);
    exe_cpp.linkLibCpp();
    exe_cpp.single_threaded = single_threaded;
    const os_tag = target.getOsTag();
    // macos C++ exceptions could be compiled, but not being catched,
    // additional support is required, possibly unwind + DWARF CFI
    if (target.getCpuArch().isWasm() or os_tag == .macos) {
        exe_cpp.defineCMacro("_LIBCPP_NO_EXCEPTIONS", null);
    }

    switch (os_tag) {
        .windows => {
            // https://github.com/ziglang/zig/issues/8531
            exe_cpp.want_lto = false;
        },
        .macos => {
            // https://github.com/ziglang/zig/issues/8680
            exe_cpp.want_lto = false;
            exe_c.want_lto = false;
        },
        else => {},
    }

    const run_c_cmd = exe_c.run();
    if (run_c_cmd.isRunnable()) {
        test_step.dependOn(&run_c_cmd.step);
    } else {
        test_step.dependOn(&exe_c.step);
    }

    const run_cpp_cmd = exe_cpp.run();
    if (run_cpp_cmd.isRunnable()) {
        test_step.dependOn(&run_cpp_cmd.step);
    } else {
        test_step.dependOn(&exe_cpp.step);
    }
}

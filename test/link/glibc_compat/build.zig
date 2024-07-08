const std = @import("std");
const builtin = @import("builtin");

// To run executables linked against a specific glibc version, the
// run-time glibc version needs to be new enough.  Check the host's glibc
// version.  Note that this does not allow for translation/vm/emulation
// services to run these tests.
const running_glibc_ver: ?std.SemanticVersion = switch (builtin.os.tag) {
    .linux => builtin.os.version_range.linux.glibc,
    else => null,
};

pub fn build(b: *std.Build) void {
    const test_step = b.step("test", "Test");
    b.default_step = test_step;

    for ([_][]const u8{ "aarch64-linux-gnu.2.27", "aarch64-linux-gnu.2.34" }) |t| {
        const exe = b.addExecutable(.{
            .name = t,
            .target = b.resolveTargetQuery(std.Target.Query.parse(
                .{ .arch_os_abi = t },
            ) catch unreachable),
        });
        exe.addCSourceFile(.{ .file = b.path("main.c") });
        exe.linkLibC();
        // TODO: actually test the output
        _ = exe.getEmittedBin();
        test_step.dependOn(&exe.step);
    }

    // Build & run a C test case against a sampling of supported glibc versions
    for ([_][]const u8{
        // "native-linux-gnu.2.0", // fails with a pile of missing symbols.
        "native-linux-gnu.2.2.5",
        "native-linux-gnu.2.4",
        "native-linux-gnu.2.12",
        "native-linux-gnu.2.16",
        "native-linux-gnu.2.22",
        "native-linux-gnu.2.28",
        "native-linux-gnu.2.33",
        "native-linux-gnu.2.38",
        "native-linux-gnu",
    }) |t| {
        const target = b.resolveTargetQuery(std.Target.Query.parse(
            .{ .arch_os_abi = t },
        ) catch unreachable);

        const glibc_ver = target.result.os.version_range.linux.glibc;

        // only build test if glibc version supports the architecture
        if (target.result.cpu.arch.isAARCH64()) {
            if (glibc_ver.order(.{ .major = 2, .minor = 17, .patch = 0 }) == .lt) {
                continue;
            }
        }

        const exe = b.addExecutable(.{
            .name = t,
            .target = target,
        });
        exe.addCSourceFile(.{ .file = b.path("glibc_runtime_check.c") });
        exe.linkLibC();

        // Only try running the test if the host glibc is known to be good enough.  Ideally, the Zig
        // test runner would be able to check this, but see https://github.com/ziglang/zig/pull/17702#issuecomment-1831310453
        if (running_glibc_ver) |running_ver| {
            if (glibc_ver.order(running_ver) == .lt) {
                const run_cmd = b.addRunArtifact(exe);
                run_cmd.skip_foreign_checks = true;
                run_cmd.expectExitCode(0);

                test_step.dependOn(&run_cmd.step);
            }
        }
        const check = exe.checkObject();

        // __errno_location is always a dynamically linked symbol
        check.checkInDynamicSymtab();
        check.checkExact("0 0 UND FUNC GLOBAL DEFAULT __errno_location");

        // before v2.32 fstat redirects through __fxstat, afterwards its a
        // normal dynamic symbol
        check.checkInDynamicSymtab();
        if (glibc_ver.order(.{ .major = 2, .minor = 32, .patch = 0 }) == .lt) {
            check.checkExact("0 0 UND FUNC GLOBAL DEFAULT __fxstat");

            check.checkInSymtab();
            check.checkContains("FUNC LOCAL HIDDEN fstat");
        } else {
            check.checkExact("0 0 UND FUNC GLOBAL DEFAULT fstat");

            check.checkInSymtab();
            check.checkNotPresent("__fxstat");
        }

        // before v2.26 reallocarray is not supported
        check.checkInDynamicSymtab();
        if (glibc_ver.order(.{ .major = 2, .minor = 26, .patch = 0 }) == .lt) {
            check.checkNotPresent("reallocarray");
        } else {
            check.checkExact("0 0 UND FUNC GLOBAL DEFAULT reallocarray");
        }

        // before v2.38 strlcpy is not supported
        check.checkInDynamicSymtab();
        if (glibc_ver.order(.{ .major = 2, .minor = 38, .patch = 0 }) == .lt) {
            check.checkNotPresent("strlcpy");
        } else {
            check.checkExact("0 0 UND FUNC GLOBAL DEFAULT strlcpy");
        }

        // v2.16 introduced getauxval()
        check.checkInDynamicSymtab();
        if (glibc_ver.order(.{ .major = 2, .minor = 16, .patch = 0 }) == .lt) {
            check.checkNotPresent("getauxval");
        } else {
            check.checkExact("0 0 UND FUNC GLOBAL DEFAULT getauxval");
        }

        // Always have dynamic "exit", "pow", and "powf" references
        check.checkInDynamicSymtab();
        check.checkExact("0 0 UND FUNC GLOBAL DEFAULT exit");
        check.checkInDynamicSymtab();
        check.checkExact("0 0 UND FUNC GLOBAL DEFAULT pow");
        check.checkInDynamicSymtab();
        check.checkExact("0 0 UND FUNC GLOBAL DEFAULT powf");

        // An atexit local symbol is defined, and depends on undefined dynamic
        // __cxa_atexit.
        check.checkInSymtab();
        check.checkContains("FUNC LOCAL HIDDEN atexit");
        check.checkInDynamicSymtab();
        check.checkExact("0 0 UND FUNC GLOBAL DEFAULT __cxa_atexit");

        test_step.dependOn(&check.step);
    }

    // Build & run a Zig test case against a sampling of supported glibc versions
    for ([_][]const u8{
        "native-linux-gnu.2.17", // Currently oldest supported, see #17769
        "native-linux-gnu.2.23",
        "native-linux-gnu.2.28",
        "native-linux-gnu.2.33",
        "native-linux-gnu.2.38",
        "native-linux-gnu",
    }) |t| {
        const target = b.resolveTargetQuery(std.Target.Query.parse(
            .{ .arch_os_abi = t },
        ) catch unreachable);

        const glibc_ver = target.result.os.version_range.linux.glibc;

        const exe = b.addExecutable(.{
            .name = t,
            .root_source_file = b.path("glibc_runtime_check.zig"),
            .target = target,
        });
        exe.linkLibC();

        // Only try running the test if the host glibc is known to be good enough.  Ideally, the Zig
        // test runner would be able to check this, but see https://github.com/ziglang/zig/pull/17702#issuecomment-1831310453
        if (running_glibc_ver) |running_ver| {
            if (glibc_ver.order(running_ver) == .lt) {
                const run_cmd = b.addRunArtifact(exe);
                run_cmd.skip_foreign_checks = true;
                run_cmd.expectExitCode(0);

                test_step.dependOn(&run_cmd.step);
            }
        }
        const check = exe.checkObject();

        // __errno_location is always a dynamically linked symbol
        check.checkInDynamicSymtab();
        check.checkExact("0 0 UND FUNC GLOBAL DEFAULT __errno_location");

        // before v2.32 fstatat redirects through __fxstatat, afterwards its a
        // normal dynamic symbol
        if (glibc_ver.order(.{ .major = 2, .minor = 32, .patch = 0 }) == .lt) {
            check.checkInDynamicSymtab();
            check.checkExact("0 0 UND FUNC GLOBAL DEFAULT __fxstatat");

            check.checkInSymtab();
            check.checkContains("FUNC LOCAL HIDDEN fstatat");
        } else {
            check.checkInDynamicSymtab();
            check.checkExact("0 0 UND FUNC GLOBAL DEFAULT fstatat");

            check.checkInSymtab();
            check.checkNotPresent("FUNC LOCAL HIDDEN fstatat");
        }

        // before v2.26 reallocarray is not supported
        if (glibc_ver.order(.{ .major = 2, .minor = 26, .patch = 0 }) == .lt) {
            check.checkInDynamicSymtab();
            check.checkNotPresent("reallocarray");
        } else {
            check.checkInDynamicSymtab();
            check.checkExact("0 0 UND FUNC GLOBAL DEFAULT reallocarray");
        }

        // before v2.38 strlcpy is not supported
        if (glibc_ver.order(.{ .major = 2, .minor = 38, .patch = 0 }) == .lt) {
            check.checkInDynamicSymtab();
            check.checkNotPresent("strlcpy");
        } else {
            check.checkInDynamicSymtab();
            check.checkExact("0 0 UND FUNC GLOBAL DEFAULT strlcpy");
        }

        // v2.16 introduced getauxval(), so always present
        check.checkInDynamicSymtab();
        check.checkExact("0 0 UND FUNC GLOBAL DEFAULT getauxval");

        // Always have a dynamic "exit" reference
        check.checkInDynamicSymtab();
        check.checkExact("0 0 UND FUNC GLOBAL DEFAULT exit");

        // An atexit local symbol is defined, and depends on undefined dynamic
        // __cxa_atexit.
        check.checkInSymtab();
        check.checkContains("FUNC LOCAL HIDDEN atexit");
        check.checkInDynamicSymtab();
        check.checkExact("0 0 UND FUNC GLOBAL DEFAULT __cxa_atexit");

        test_step.dependOn(&check.step);
    }
}

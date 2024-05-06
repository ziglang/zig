//! Here we test our MachO linker for correctness and functionality.

pub fn testAll(b: *Build, build_opts: BuildOptions) *Step {
    const macho_step = b.step("test-macho", "Run MachO tests");

    const x86_64_target = b.resolveTargetQuery(.{
        .cpu_arch = .x86_64,
        .os_tag = .macos,
    });
    const aarch64_target = b.resolveTargetQuery(.{
        .cpu_arch = .aarch64,
        .os_tag = .macos,
    });

    const default_target = switch (builtin.cpu.arch) {
        .x86_64, .aarch64 => b.resolveTargetQuery(.{
            .os_tag = .macos,
        }),
        else => aarch64_target,
    };

    // Exercise linker with self-hosted backend (no LLVM)
    macho_step.dependOn(testEmptyZig(b, .{ .use_llvm = false, .target = x86_64_target }));
    macho_step.dependOn(testHelloZig(b, .{ .use_llvm = false, .target = x86_64_target }));
    macho_step.dependOn(testLinkingStaticLib(b, .{ .use_llvm = false, .target = x86_64_target }));
    macho_step.dependOn(testReexportsZig(b, .{ .use_llvm = false, .target = x86_64_target }));
    macho_step.dependOn(testRelocatableZig(b, .{ .use_llvm = false, .target = x86_64_target }));

    // Exercise linker with LLVM backend
    macho_step.dependOn(testDeadStrip(b, .{ .target = default_target }));
    macho_step.dependOn(testEmptyObject(b, .{ .target = default_target }));
    macho_step.dependOn(testEmptyZig(b, .{ .target = default_target }));
    macho_step.dependOn(testEntryPoint(b, .{ .target = default_target }));
    macho_step.dependOn(testHeaderWeakFlags(b, .{ .target = default_target }));
    macho_step.dependOn(testHelloC(b, .{ .target = default_target }));
    macho_step.dependOn(testHelloZig(b, .{ .target = default_target }));
    macho_step.dependOn(testLargeBss(b, .{ .target = default_target }));
    macho_step.dependOn(testLayout(b, .{ .target = default_target }));
    macho_step.dependOn(testLinkingStaticLib(b, .{ .target = default_target }));
    macho_step.dependOn(testLinksection(b, .{ .target = default_target }));
    macho_step.dependOn(testMhExecuteHeader(b, .{ .target = default_target }));
    macho_step.dependOn(testNoDeadStrip(b, .{ .target = default_target }));
    macho_step.dependOn(testNoExportsDylib(b, .{ .target = default_target }));
    macho_step.dependOn(testPagezeroSize(b, .{ .target = default_target }));
    macho_step.dependOn(testReexportsZig(b, .{ .target = default_target }));
    macho_step.dependOn(testRelocatable(b, .{ .target = default_target }));
    macho_step.dependOn(testRelocatableZig(b, .{ .target = default_target }));
    macho_step.dependOn(testSectionBoundarySymbols(b, .{ .target = default_target }));
    macho_step.dependOn(testSegmentBoundarySymbols(b, .{ .target = default_target }));
    macho_step.dependOn(testStackSize(b, .{ .target = default_target }));
    macho_step.dependOn(testTentative(b, .{ .target = default_target }));
    macho_step.dependOn(testThunks(b, .{ .target = aarch64_target }));
    macho_step.dependOn(testTlsLargeTbss(b, .{ .target = default_target }));
    macho_step.dependOn(testUndefinedFlag(b, .{ .target = default_target }));
    macho_step.dependOn(testUnwindInfo(b, .{ .target = default_target }));
    macho_step.dependOn(testUnwindInfoNoSubsectionsX64(b, .{ .target = x86_64_target }));
    macho_step.dependOn(testUnwindInfoNoSubsectionsArm64(b, .{ .target = aarch64_target }));
    macho_step.dependOn(testWeakBind(b, .{ .target = x86_64_target }));
    macho_step.dependOn(testWeakRef(b, .{ .target = b.resolveTargetQuery(.{
        .cpu_arch = .x86_64,
        .os_tag = .macos,
        .os_version_min = .{ .semver = .{ .major = 10, .minor = 13, .patch = 0 } },
    }) }));

    // Tests requiring symlinks when tested on Windows
    if (build_opts.has_symlinks_windows) {
        macho_step.dependOn(testEntryPointArchive(b, .{ .target = default_target }));
        macho_step.dependOn(testEntryPointDylib(b, .{ .target = default_target }));
        macho_step.dependOn(testDylib(b, .{ .target = default_target }));
        macho_step.dependOn(testDylibVersionTbd(b, .{ .target = default_target }));
        macho_step.dependOn(testNeededLibrary(b, .{ .target = default_target }));
        macho_step.dependOn(testSearchStrategy(b, .{ .target = default_target }));
        macho_step.dependOn(testTbdv3(b, .{ .target = default_target }));
        macho_step.dependOn(testTls(b, .{ .target = default_target }));
        macho_step.dependOn(testTlsPointers(b, .{ .target = default_target }));
        macho_step.dependOn(testTwoLevelNamespace(b, .{ .target = default_target }));
        macho_step.dependOn(testWeakLibrary(b, .{ .target = default_target }));

        // Tests requiring presence of macOS SDK in system path
        if (build_opts.has_macos_sdk) {
            macho_step.dependOn(testDeadStripDylibs(b, .{ .target = b.host }));
            macho_step.dependOn(testHeaderpad(b, .{ .target = b.host }));
            macho_step.dependOn(testLinkDirectlyCppTbd(b, .{ .target = b.host }));
            macho_step.dependOn(testNeededFramework(b, .{ .target = b.host }));
            macho_step.dependOn(testObjc(b, .{ .target = b.host }));
            macho_step.dependOn(testObjcpp(b, .{ .target = b.host }));
            macho_step.dependOn(testWeakFramework(b, .{ .target = b.host }));
        }
    }

    return macho_step;
}

fn testDeadStrip(b: *Build, opts: Options) *Step {
    const test_step = addTestStep(b, "dead-strip", opts);

    const obj = addObject(b, opts, .{ .name = "a", .cpp_source_bytes = 
    \\#include <stdio.h>
    \\int two() { return 2; }
    \\int live_var1 = 1;
    \\int live_var2 = two();
    \\int dead_var1 = 3;
    \\int dead_var2 = 4;
    \\void live_fn1() {}
    \\void live_fn2() { live_fn1(); }
    \\void dead_fn1() {}
    \\void dead_fn2() { dead_fn1(); }
    \\int main() {
    \\  printf("%d %d\n", live_var1, live_var2);
    \\  live_fn2();
    \\}
    });

    {
        const exe = addExecutable(b, opts, .{ .name = "no_dead_strip" });
        exe.addObject(obj);
        exe.link_gc_sections = false;

        const check = exe.checkObject();
        check.checkInSymtab();
        check.checkContains("live_var1");
        check.checkInSymtab();
        check.checkContains("live_var2");
        check.checkInSymtab();
        check.checkContains("dead_var1");
        check.checkInSymtab();
        check.checkContains("dead_var2");
        check.checkInSymtab();
        check.checkContains("live_fn1");
        check.checkInSymtab();
        check.checkContains("live_fn2");
        check.checkInSymtab();
        check.checkContains("dead_fn1");
        check.checkInSymtab();
        check.checkContains("dead_fn2");
        test_step.dependOn(&check.step);

        const run = addRunArtifact(exe);
        run.expectStdOutEqual("1 2\n");
        test_step.dependOn(&run.step);
    }

    {
        const exe = addExecutable(b, opts, .{ .name = "yes_dead_strip" });
        exe.addObject(obj);
        exe.link_gc_sections = true;

        const check = exe.checkObject();
        check.checkInSymtab();
        check.checkContains("live_var1");
        check.checkInSymtab();
        check.checkContains("live_var2");
        check.checkInSymtab();
        check.checkNotPresent("dead_var1");
        check.checkInSymtab();
        check.checkNotPresent("dead_var2");
        check.checkInSymtab();
        check.checkContains("live_fn1");
        check.checkInSymtab();
        check.checkContains("live_fn2");
        check.checkInSymtab();
        check.checkNotPresent("dead_fn1");
        check.checkInSymtab();
        check.checkNotPresent("dead_fn2");
        test_step.dependOn(&check.step);

        const run = addRunArtifact(exe);
        run.expectStdOutEqual("1 2\n");
        test_step.dependOn(&run.step);
    }

    return test_step;
}

fn testDeadStripDylibs(b: *Build, opts: Options) *Step {
    const test_step = addTestStep(b, "dead-strip-dylibs", opts);

    const main_o = addObject(b, opts, .{ .name = "main", .c_source_bytes = 
    \\#include <objc/runtime.h>
    \\int main() {
    \\  if (objc_getClass("NSObject") == 0) {
    \\    return -1;
    \\  }
    \\  if (objc_getClass("NSApplication") == 0) {
    \\    return -2;
    \\  }
    \\  return 0;
    \\}
    });

    {
        const exe = addExecutable(b, opts, .{ .name = "main1" });
        exe.addObject(main_o);
        exe.root_module.linkFramework("Cocoa", .{});

        const check = exe.checkObject();
        check.checkInHeaders();
        check.checkExact("cmd LOAD_DYLIB");
        check.checkContains("Cocoa");
        check.checkInHeaders();
        check.checkExact("cmd LOAD_DYLIB");
        check.checkContains("libobjc");
        test_step.dependOn(&check.step);

        const run = addRunArtifact(exe);
        run.expectExitCode(0);
        test_step.dependOn(&run.step);
    }

    {
        const exe = addExecutable(b, opts, .{ .name = "main2" });
        exe.addObject(main_o);
        exe.root_module.linkFramework("Cocoa", .{});
        exe.dead_strip_dylibs = true;

        const run = addRunArtifact(exe);
        run.expectExitCode(@as(u8, @bitCast(@as(i8, -2))));
        test_step.dependOn(&run.step);
    }

    return test_step;
}

fn testDylib(b: *Build, opts: Options) *Step {
    const test_step = addTestStep(b, "dylib", opts);

    const dylib = addSharedLibrary(b, opts, .{ .name = "a", .c_source_bytes = 
    \\#include<stdio.h>
    \\char world[] = "world";
    \\char* hello() {
    \\  return "Hello";
    \\}
    });

    const check = dylib.checkObject();
    check.checkInHeaders();
    check.checkExact("header");
    check.checkNotPresent("PIE");
    test_step.dependOn(&check.step);

    const exe = addExecutable(b, opts, .{ .name = "main", .c_source_bytes = 
    \\#include<stdio.h>
    \\char* hello();
    \\extern char world[];
    \\int main() {
    \\  printf("%s %s", hello(), world);
    \\  return 0;
    \\}
    });
    exe.root_module.linkSystemLibrary("a", .{});
    exe.root_module.addLibraryPath(dylib.getEmittedBinDirectory());
    exe.root_module.addRPath(dylib.getEmittedBinDirectory());

    const run = addRunArtifact(exe);
    run.expectStdOutEqual("Hello world");
    test_step.dependOn(&run.step);

    return test_step;
}

fn testDylibVersionTbd(b: *Build, opts: Options) *Step {
    const test_step = addTestStep(b, "dylib-version-tbd", opts);

    const tbd = tbd: {
        const wf = WriteFile.create(b);
        break :tbd wf.add("liba.tbd",
            \\--- !tapi-tbd
            \\tbd-version:     4
            \\targets:         [ x86_64-macos, arm64-macos ]
            \\uuids:
            \\  - target:          x86_64-macos
            \\    value:           DEADBEEF
            \\  - target:          arm64-macos
            \\    value:           BEEFDEAD
            \\install-name:    '@rpath/liba.dylib'
            \\current-version: 1.2
            \\exports:
            \\  - targets:     [ x86_64-macos, arm64-macos ]
            \\    symbols:     [ _foo ]
        );
    };

    const exe = addExecutable(b, opts, .{ .name = "main", .c_source_bytes = "int main() {}" });
    exe.root_module.linkSystemLibrary("a", .{});
    exe.root_module.addLibraryPath(tbd.dirname());

    const check = exe.checkObject();
    check.checkInHeaders();
    check.checkExact("cmd LOAD_DYLIB");
    check.checkExact("name @rpath/liba.dylib");
    check.checkExact("current version 10200");
    test_step.dependOn(&check.step);

    return test_step;
}

fn testEmptyObject(b: *Build, opts: Options) *Step {
    const test_step = addTestStep(b, "empty-object", opts);

    const empty = addObject(b, opts, .{ .name = "empty", .c_source_bytes = "" });

    const exe = addExecutable(b, opts, .{ .name = "main", .c_source_bytes = 
    \\#include <stdio.h>
    \\int main() {
    \\  printf("Hello world!");
    \\}
    });
    exe.addObject(empty);

    const run = addRunArtifact(exe);
    run.expectStdOutEqual("Hello world!");
    test_step.dependOn(&run.step);

    return test_step;
}

fn testEmptyZig(b: *Build, opts: Options) *Step {
    const test_step = addTestStep(b, "empty-zig", opts);

    const exe = addExecutable(b, opts, .{ .name = "empty", .zig_source_bytes = "pub fn main() void {}" });

    const run = addRunArtifact(exe);
    run.expectExitCode(0);
    test_step.dependOn(&run.step);

    return test_step;
}

fn testEntryPoint(b: *Build, opts: Options) *Step {
    const test_step = addTestStep(b, "entry-point", opts);

    const exe = addExecutable(b, opts, .{ .name = "main", .c_source_bytes = 
    \\#include<stdio.h>
    \\int non_main() {
    \\  printf("%d", 42);
    \\  return 0;
    \\}
    });
    exe.entry = .{ .symbol_name = "_non_main" };

    const run = addRunArtifact(exe);
    run.expectStdOutEqual("42");
    test_step.dependOn(&run.step);

    const check = exe.checkObject();
    check.checkInHeaders();
    check.checkExact("segname __TEXT");
    check.checkExtract("vmaddr {vmaddr}");
    check.checkInHeaders();
    check.checkExact("cmd MAIN");
    check.checkExtract("entryoff {entryoff}");
    check.checkInSymtab();
    check.checkExtract("{n_value} (__TEXT,__text) external _non_main");
    check.checkComputeCompare("vmaddr entryoff +", .{ .op = .eq, .value = .{ .variable = "n_value" } });
    test_step.dependOn(&check.step);

    return test_step;
}

fn testEntryPointArchive(b: *Build, opts: Options) *Step {
    const test_step = addTestStep(b, "entry-point-archive", opts);

    const lib = addStaticLibrary(b, opts, .{ .name = "main", .c_source_bytes = "int main() { return 0; }" });

    {
        const exe = addExecutable(b, opts, .{ .name = "main", .c_source_bytes = "" });
        exe.root_module.linkSystemLibrary("main", .{});
        exe.root_module.addLibraryPath(lib.getEmittedBinDirectory());

        const run = addRunArtifact(exe);
        run.expectExitCode(0);
        test_step.dependOn(&run.step);
    }

    {
        const exe = addExecutable(b, opts, .{ .name = "main", .c_source_bytes = "" });
        exe.root_module.linkSystemLibrary("main", .{});
        exe.root_module.addLibraryPath(lib.getEmittedBinDirectory());
        exe.link_gc_sections = true;

        const run = addRunArtifact(exe);
        run.expectExitCode(0);
        test_step.dependOn(&run.step);
    }

    return test_step;
}

fn testEntryPointDylib(b: *Build, opts: Options) *Step {
    const test_step = addTestStep(b, "entry-point-dylib", opts);

    const dylib = addSharedLibrary(b, opts, .{ .name = "a" });
    addCSourceBytes(dylib,
        \\extern int my_main();
        \\int bootstrap() {
        \\  return my_main();
        \\}
    , &.{});
    dylib.linker_allow_shlib_undefined = true;

    const exe = addExecutable(b, opts, .{ .name = "main" });
    addCSourceBytes(dylib,
        \\#include<stdio.h>
        \\int my_main() {
        \\  fprintf(stdout, "Hello!\n");
        \\  return 0;
        \\}
    , &.{});
    exe.linkLibrary(dylib);
    exe.entry = .{ .symbol_name = "_bootstrap" };
    exe.forceUndefinedSymbol("_my_main");

    const check = exe.checkObject();
    check.checkInHeaders();
    check.checkExact("segname __TEXT");
    check.checkExtract("vmaddr {text_vmaddr}");
    check.checkInHeaders();
    check.checkExact("sectname __stubs");
    check.checkExtract("addr {stubs_vmaddr}");
    check.checkInHeaders();
    check.checkExact("sectname __stubs");
    check.checkExtract("size {stubs_vmsize}");
    check.checkInHeaders();
    check.checkExact("cmd MAIN");
    check.checkExtract("entryoff {entryoff}");
    check.checkComputeCompare("text_vmaddr entryoff +", .{
        .op = .gte,
        .value = .{ .variable = "stubs_vmaddr" }, // The entrypoint should be a synthetic stub
    });
    check.checkComputeCompare("text_vmaddr entryoff + stubs_vmaddr -", .{
        .op = .lt,
        .value = .{ .variable = "stubs_vmsize" }, // The entrypoint should be a synthetic stub
    });
    test_step.dependOn(&check.step);

    const run = addRunArtifact(exe);
    run.expectStdOutEqual("Hello!\n");
    test_step.dependOn(&run.step);

    return test_step;
}

fn testHeaderpad(b: *Build, opts: Options) *Step {
    const test_step = addTestStep(b, "headerpad", opts);

    const addExe = struct {
        fn addExe(bb: *Build, o: Options, name: []const u8) *Compile {
            const exe = addExecutable(bb, o, .{
                .name = name,
                .c_source_bytes = "int main() { return 0; }",
            });
            exe.root_module.linkFramework("CoreFoundation", .{});
            exe.root_module.linkFramework("Foundation", .{});
            exe.root_module.linkFramework("Cocoa", .{});
            exe.root_module.linkFramework("CoreGraphics", .{});
            exe.root_module.linkFramework("CoreHaptics", .{});
            exe.root_module.linkFramework("CoreAudio", .{});
            exe.root_module.linkFramework("AVFoundation", .{});
            exe.root_module.linkFramework("CoreImage", .{});
            exe.root_module.linkFramework("CoreLocation", .{});
            exe.root_module.linkFramework("CoreML", .{});
            exe.root_module.linkFramework("CoreVideo", .{});
            exe.root_module.linkFramework("CoreText", .{});
            exe.root_module.linkFramework("CryptoKit", .{});
            exe.root_module.linkFramework("GameKit", .{});
            exe.root_module.linkFramework("SwiftUI", .{});
            exe.root_module.linkFramework("StoreKit", .{});
            exe.root_module.linkFramework("SpriteKit", .{});
            return exe;
        }
    }.addExe;

    {
        const exe = addExe(b, opts, "main1");
        exe.headerpad_max_install_names = true;

        const check = exe.checkObject();
        check.checkInHeaders();
        check.checkExact("sectname __text");
        check.checkExtract("offset {offset}");
        switch (opts.target.result.cpu.arch) {
            .aarch64 => check.checkComputeCompare("offset", .{ .op = .gte, .value = .{ .literal = 0x4000 } }),
            .x86_64 => check.checkComputeCompare("offset", .{ .op = .gte, .value = .{ .literal = 0x1000 } }),
            else => unreachable,
        }
        test_step.dependOn(&check.step);

        const run = addRunArtifact(exe);
        run.expectExitCode(0);
        test_step.dependOn(&run.step);
    }

    {
        const exe = addExe(b, opts, "main2");
        exe.headerpad_size = 0x10000;

        const check = exe.checkObject();
        check.checkInHeaders();
        check.checkExact("sectname __text");
        check.checkExtract("offset {offset}");
        check.checkComputeCompare("offset", .{ .op = .gte, .value = .{ .literal = 0x10000 } });
        test_step.dependOn(&check.step);

        const run = addRunArtifact(exe);
        run.expectExitCode(0);
        test_step.dependOn(&run.step);
    }

    {
        const exe = addExe(b, opts, "main3");
        exe.headerpad_max_install_names = true;
        exe.headerpad_size = 0x10000;

        const check = exe.checkObject();
        check.checkInHeaders();
        check.checkExact("sectname __text");
        check.checkExtract("offset {offset}");
        check.checkComputeCompare("offset", .{ .op = .gte, .value = .{ .literal = 0x10000 } });
        test_step.dependOn(&check.step);

        const run = addRunArtifact(exe);
        run.expectExitCode(0);
        test_step.dependOn(&run.step);
    }

    {
        const exe = addExe(b, opts, "main4");
        exe.headerpad_max_install_names = true;
        exe.headerpad_size = 0x1000;

        const check = exe.checkObject();
        check.checkInHeaders();
        check.checkExact("sectname __text");
        check.checkExtract("offset {offset}");
        switch (opts.target.result.cpu.arch) {
            .aarch64 => check.checkComputeCompare("offset", .{ .op = .gte, .value = .{ .literal = 0x4000 } }),
            .x86_64 => check.checkComputeCompare("offset", .{ .op = .gte, .value = .{ .literal = 0x1000 } }),
            else => unreachable,
        }
        test_step.dependOn(&check.step);

        const run = addRunArtifact(exe);
        run.expectExitCode(0);
        test_step.dependOn(&run.step);
    }

    return test_step;
}

// Adapted from https://github.com/llvm/llvm-project/blob/main/lld/test/MachO/weak-header-flags.s
fn testHeaderWeakFlags(b: *Build, opts: Options) *Step {
    const test_step = addTestStep(b, "header-weak-flags", opts);

    const obj1 = addObject(b, opts, .{ .name = "a", .asm_source_bytes = 
    \\.globl _x
    \\.weak_definition _x
    \\_x:
    \\ ret
    });

    const lib = addSharedLibrary(b, opts, .{ .name = "a" });
    lib.addObject(obj1);

    {
        const exe = addExecutable(b, opts, .{ .name = "main1", .c_source_bytes = "int main() { return 0; }" });
        exe.addObject(obj1);

        const check = exe.checkObject();
        check.checkInHeaders();
        check.checkExact("header");
        check.checkContains("WEAK_DEFINES");
        check.checkInHeaders();
        check.checkExact("header");
        check.checkContains("BINDS_TO_WEAK");
        check.checkInExports();
        check.checkExtract("[WEAK] {vmaddr} _x");
        test_step.dependOn(&check.step);
    }

    {
        const obj = addObject(b, opts, .{ .name = "b" });

        switch (opts.target.result.cpu.arch) {
            .aarch64 => addAsmSourceBytes(obj,
                \\.globl _main
                \\_main:
                \\  bl _x
                \\  ret
            ),
            .x86_64 => addAsmSourceBytes(obj,
                \\.globl _main
                \\_main:
                \\  callq _x
                \\  ret
            ),
            else => unreachable,
        }

        const exe = addExecutable(b, opts, .{ .name = "main2" });
        exe.linkLibrary(lib);
        exe.addObject(obj);

        const check = exe.checkObject();
        check.checkInHeaders();
        check.checkExact("header");
        check.checkNotPresent("WEAK_DEFINES");
        check.checkInHeaders();
        check.checkExact("header");
        check.checkContains("BINDS_TO_WEAK");
        check.checkInExports();
        check.checkNotPresent("[WEAK] {vmaddr} _x");
        test_step.dependOn(&check.step);
    }

    {
        const exe = addExecutable(b, opts, .{ .name = "main3", .asm_source_bytes = 
        \\.globl _main, _x
        \\_x:
        \\
        \\_main:
        \\  ret
        });
        exe.linkLibrary(lib);

        const check = exe.checkObject();
        check.checkInHeaders();
        check.checkExact("header");
        check.checkNotPresent("WEAK_DEFINES");
        check.checkInHeaders();
        check.checkExact("header");
        check.checkNotPresent("BINDS_TO_WEAK");
        test_step.dependOn(&check.step);
    }

    return test_step;
}

fn testHelloC(b: *Build, opts: Options) *Step {
    const test_step = addTestStep(b, "hello-c", opts);

    const exe = addExecutable(b, opts, .{ .name = "main", .c_source_bytes = 
    \\#include <stdio.h>
    \\int main() { 
    \\  printf("Hello world!\n");
    \\  return 0;
    \\}
    });

    const run = addRunArtifact(exe);
    run.expectStdOutEqual("Hello world!\n");
    test_step.dependOn(&run.step);

    const check = exe.checkObject();
    check.checkInHeaders();
    check.checkExact("header");
    check.checkContains("PIE");
    test_step.dependOn(&check.step);

    return test_step;
}

fn testHelloZig(b: *Build, opts: Options) *Step {
    const test_step = addTestStep(b, "hello-zig", opts);

    const exe = addExecutable(b, opts, .{ .name = "main", .zig_source_bytes = 
    \\const std = @import("std");
    \\pub fn main() void {
    \\    std.io.getStdOut().writer().print("Hello world!\n", .{}) catch unreachable;
    \\}
    });

    const run = addRunArtifact(exe);
    run.expectStdOutEqual("Hello world!\n");
    test_step.dependOn(&run.step);

    return test_step;
}

fn testLargeBss(b: *Build, opts: Options) *Step {
    const test_step = addTestStep(b, "large-bss", opts);

    // TODO this test used use a 4GB zerofill section but this actually fails and causes every
    // linker I tried misbehave in different ways. This only happened on arm64. I thought that
    // maybe S_GB_ZEROFILL section is an answer to this but it doesn't seem supported by dyld
    // anymore. When I get some free time I will re-investigate this.
    const exe = addExecutable(b, opts, .{ .name = "main", .c_source_bytes = 
    \\char arr[0x1000000];
    \\int main() {
    \\  return arr[2000];
    \\}
    });

    const run = addRunArtifact(exe);
    run.expectExitCode(0);
    test_step.dependOn(&run.step);

    return test_step;
}

fn testLayout(b: *Build, opts: Options) *Step {
    const test_step = addTestStep(b, "layout", opts);

    const exe = addExecutable(b, opts, .{ .name = "main", .c_source_bytes = 
    \\#include <stdio.h>
    \\int main() {
    \\  printf("Hello world!");
    \\  return 0;
    \\}
    });

    const check = exe.checkObject();
    check.checkInHeaders();
    check.checkExact("cmd SEGMENT_64");
    check.checkExact("segname __LINKEDIT");
    check.checkExtract("fileoff {fileoff}");
    check.checkExtract("filesz {filesz}");
    check.checkInHeaders();
    check.checkExact("cmd DYLD_INFO_ONLY");
    check.checkExtract("rebaseoff {rebaseoff}");
    check.checkExtract("rebasesize {rebasesize}");
    check.checkExtract("bindoff {bindoff}");
    check.checkExtract("bindsize {bindsize}");
    check.checkExtract("lazybindoff {lazybindoff}");
    check.checkExtract("lazybindsize {lazybindsize}");
    check.checkExtract("exportoff {exportoff}");
    check.checkExtract("exportsize {exportsize}");
    check.checkInHeaders();
    check.checkExact("cmd FUNCTION_STARTS");
    check.checkExtract("dataoff {fstartoff}");
    check.checkExtract("datasize {fstartsize}");
    check.checkInHeaders();
    check.checkExact("cmd DATA_IN_CODE");
    check.checkExtract("dataoff {diceoff}");
    check.checkExtract("datasize {dicesize}");
    check.checkInHeaders();
    check.checkExact("cmd SYMTAB");
    check.checkExtract("symoff {symoff}");
    check.checkExtract("nsyms {symnsyms}");
    check.checkExtract("stroff {stroff}");
    check.checkExtract("strsize {strsize}");
    check.checkInHeaders();
    check.checkExact("cmd DYSYMTAB");
    check.checkExtract("indirectsymoff {dysymoff}");
    check.checkExtract("nindirectsyms {dysymnsyms}");

    switch (opts.target.result.cpu.arch) {
        .aarch64 => {
            check.checkInHeaders();
            check.checkExact("cmd CODE_SIGNATURE");
            check.checkExtract("dataoff {codesigoff}");
            check.checkExtract("datasize {codesigsize}");
        },
        .x86_64 => {},
        else => unreachable,
    }

    // DYLD_INFO_ONLY subsections are in order: rebase < bind < lazy < export,
    // and there are no gaps between them
    check.checkComputeCompare("rebaseoff rebasesize +", .{ .op = .eq, .value = .{ .variable = "bindoff" } });
    check.checkComputeCompare("bindoff bindsize +", .{ .op = .eq, .value = .{ .variable = "lazybindoff" } });
    check.checkComputeCompare("lazybindoff lazybindsize +", .{ .op = .eq, .value = .{ .variable = "exportoff" } });

    // FUNCTION_STARTS directly follows DYLD_INFO_ONLY (no gap)
    check.checkComputeCompare("exportoff exportsize +", .{ .op = .eq, .value = .{ .variable = "fstartoff" } });

    // DATA_IN_CODE directly follows FUNCTION_STARTS (no gap)
    check.checkComputeCompare("fstartoff fstartsize +", .{ .op = .eq, .value = .{ .variable = "diceoff" } });

    // SYMTAB directly follows DATA_IN_CODE (no gap)
    check.checkComputeCompare("diceoff dicesize +", .{ .op = .eq, .value = .{ .variable = "symoff" } });

    // DYSYMTAB directly follows SYMTAB (no gap)
    check.checkComputeCompare("symnsyms 16 symoff * +", .{ .op = .eq, .value = .{ .variable = "dysymoff" } });

    // STRTAB follows DYSYMTAB with possible gap
    check.checkComputeCompare("dysymnsyms 4 dysymoff * +", .{ .op = .lte, .value = .{ .variable = "stroff" } });

    // all LINKEDIT sections apart from CODE_SIGNATURE are 8-bytes aligned
    check.checkComputeCompare("rebaseoff 8 %", .{ .op = .eq, .value = .{ .literal = 0 } });
    check.checkComputeCompare("bindoff 8 %", .{ .op = .eq, .value = .{ .literal = 0 } });
    check.checkComputeCompare("lazybindoff 8 %", .{ .op = .eq, .value = .{ .literal = 0 } });
    check.checkComputeCompare("exportoff 8 %", .{ .op = .eq, .value = .{ .literal = 0 } });
    check.checkComputeCompare("fstartoff 8 %", .{ .op = .eq, .value = .{ .literal = 0 } });
    check.checkComputeCompare("diceoff 8 %", .{ .op = .eq, .value = .{ .literal = 0 } });
    check.checkComputeCompare("symoff 8 %", .{ .op = .eq, .value = .{ .literal = 0 } });
    check.checkComputeCompare("stroff 8 %", .{ .op = .eq, .value = .{ .literal = 0 } });
    check.checkComputeCompare("dysymoff 8 %", .{ .op = .eq, .value = .{ .literal = 0 } });

    switch (opts.target.result.cpu.arch) {
        .aarch64 => {
            // LINKEDIT segment does not extend beyond, or does not include, CODE_SIGNATURE data
            check.checkComputeCompare("fileoff filesz codesigoff codesigsize + - -", .{
                .op = .eq,
                .value = .{ .literal = 0 },
            });

            // CODE_SIGNATURE data offset is 16-bytes aligned
            check.checkComputeCompare("codesigoff 16 %", .{ .op = .eq, .value = .{ .literal = 0 } });
        },
        .x86_64 => {
            // LINKEDIT segment does not extend beyond, or does not include, strtab data
            check.checkComputeCompare("fileoff filesz stroff strsize + - -", .{
                .op = .eq,
                .value = .{ .literal = 0 },
            });
        },
        else => unreachable,
    }

    test_step.dependOn(&check.step);

    const run = addRunArtifact(exe);
    run.expectStdOutEqual("Hello world!");
    test_step.dependOn(&run.step);

    return test_step;
}

fn testLinkDirectlyCppTbd(b: *Build, opts: Options) *Step {
    const test_step = addTestStep(b, "link-directly-cpp-tbd", opts);

    const sdk = std.zig.system.darwin.getSdk(b.allocator, opts.target.result) orelse
        @panic("macOS SDK is required to run the test");

    const exe = addExecutable(b, opts, .{
        .name = "main",
        .cpp_source_bytes =
        \\#include <new>
        \\#include <cstdio>
        \\int main() {
        \\    int *x = new int;
        \\    *x = 5;
        \\    fprintf(stderr, "x: %d\n", *x);
        \\    delete x;
        \\}
        ,
        .cpp_source_flags = &.{ "-nostdlib++", "-nostdinc++" },
    });
    exe.root_module.addSystemIncludePath(b.path(b.pathJoin(&.{ sdk, "/usr/include" })));
    exe.root_module.addIncludePath(b.path(b.pathJoin(&.{ sdk, "/usr/include/c++/v1" })));
    exe.root_module.addObjectFile(b.path(b.pathJoin(&.{ sdk, "/usr/lib/libc++.tbd" })));

    const check = exe.checkObject();
    check.checkInSymtab();
    check.checkContains("[referenced dynamically] external __mh_execute_header");
    test_step.dependOn(&check.step);

    return test_step;
}

fn testLinkingStaticLib(b: *Build, opts: Options) *Step {
    const test_step = addTestStep(b, "linking-static-lib", opts);

    const obj = addObject(b, opts, .{
        .name = "bobj",
        .zig_source_bytes = "export var bar: i32 = -42;",
        .strip = true, // TODO for self-hosted, we don't really emit any valid DWARF yet since we only export a global
    });

    const lib = addStaticLibrary(b, opts, .{
        .name = "alib",
        .zig_source_bytes =
        \\export fn foo() i32 {
        \\    return 42;
        \\}
        ,
    });
    lib.addObject(obj);

    const exe = addExecutable(b, opts, .{
        .name = "testlib",
        .zig_source_bytes =
        \\const std = @import("std");
        \\extern fn foo() i32;
        \\extern var bar: i32;
        \\pub fn main() void {
        \\    std.debug.print("{d}\n", .{foo() + bar});
        \\}
        ,
    });
    exe.linkLibrary(lib);

    const run = addRunArtifact(exe);
    run.expectStdErrEqual("0\n");
    test_step.dependOn(&run.step);

    return test_step;
}

fn testLinksection(b: *Build, opts: Options) *Step {
    const test_step = addTestStep(b, "linksection", opts);

    const obj = addObject(b, opts, .{ .name = "main", .zig_source_bytes = 
    \\export var test_global: u32 linksection("__DATA,__TestGlobal") = undefined;
    \\export fn testFn() linksection("__TEXT,__TestFn") callconv(.C) void {
    \\    testGenericFn("A");
    \\}
    \\fn testGenericFn(comptime suffix: []const u8) linksection("__TEXT,__TestGenFn" ++ suffix) void {}
    });

    const check = obj.checkObject();
    check.checkInSymtab();
    check.checkContains("(__DATA,__TestGlobal) external _test_global");
    check.checkInSymtab();
    check.checkContains("(__TEXT,__TestFn) external _testFn");

    if (opts.optimize == .Debug) {
        check.checkInSymtab();
        check.checkContains("(__TEXT,__TestGenFnA) _a.testGenericFn__anon_");
    }

    test_step.dependOn(&check.step);

    return test_step;
}

fn testMhExecuteHeader(b: *Build, opts: Options) *Step {
    const test_step = addTestStep(b, "mh-execute-header", opts);

    const exe = addExecutable(b, opts, .{ .name = "main", .c_source_bytes = "int main() { return 0; }" });

    const check = exe.checkObject();
    check.checkInSymtab();
    check.checkContains("[referenced dynamically] external __mh_execute_header");
    test_step.dependOn(&check.step);

    return test_step;
}

fn testNoDeadStrip(b: *Build, opts: Options) *Step {
    const test_step = addTestStep(b, "no-dead-strip", opts);

    const exe = addExecutable(b, opts, .{ .name = "name", .c_source_bytes = 
    \\__attribute__((used)) int bogus1 = 0;
    \\int bogus2 = 0;
    \\int foo = 42;
    \\int main() {
    \\  return foo - 42;
    \\}
    });
    exe.link_gc_sections = true;

    const check = exe.checkObject();
    check.checkInSymtab();
    check.checkContains("external _bogus1");
    check.checkInSymtab();
    check.checkNotPresent("external _bogus2");
    test_step.dependOn(&check.step);

    const run = addRunArtifact(exe);
    run.expectExitCode(0);
    test_step.dependOn(&run.step);

    return test_step;
}

fn testNoExportsDylib(b: *Build, opts: Options) *Step {
    const test_step = addTestStep(b, "no-exports-dylib", opts);

    const dylib = addSharedLibrary(b, opts, .{ .name = "a", .c_source_bytes = "static void abc() {}" });

    const check = dylib.checkObject();
    check.checkInSymtab();
    check.checkNotPresent("external _abc");
    test_step.dependOn(&check.step);

    return test_step;
}

fn testNeededFramework(b: *Build, opts: Options) *Step {
    const test_step = addTestStep(b, "needed-framework", opts);

    const exe = addExecutable(b, opts, .{ .name = "main", .c_source_bytes = "int main() { return 0; }" });
    exe.root_module.linkFramework("Cocoa", .{ .needed = true });
    exe.dead_strip_dylibs = true;

    const check = exe.checkObject();
    check.checkInHeaders();
    check.checkExact("cmd LOAD_DYLIB");
    check.checkContains("Cocoa");
    test_step.dependOn(&check.step);

    const run = addRunArtifact(exe);
    run.expectExitCode(0);
    test_step.dependOn(&run.step);

    return test_step;
}

fn testNeededLibrary(b: *Build, opts: Options) *Step {
    const test_step = addTestStep(b, "needed-library", opts);

    const dylib = addSharedLibrary(b, opts, .{ .name = "a", .c_source_bytes = "int a = 42;" });

    const exe = addExecutable(b, opts, .{ .name = "main", .c_source_bytes = "int main() { return 0; }" });
    exe.root_module.linkSystemLibrary("a", .{ .needed = true });
    exe.root_module.addLibraryPath(dylib.getEmittedBinDirectory());
    exe.root_module.addRPath(dylib.getEmittedBinDirectory());
    exe.dead_strip_dylibs = true;

    const check = exe.checkObject();
    check.checkInHeaders();
    check.checkExact("cmd LOAD_DYLIB");
    check.checkContains("liba.dylib");
    test_step.dependOn(&check.step);

    const run = addRunArtifact(exe);
    run.expectExitCode(0);
    test_step.dependOn(&run.step);

    return test_step;
}

fn testObjc(b: *Build, opts: Options) *Step {
    const test_step = addTestStep(b, "objc", opts);

    const lib = addStaticLibrary(b, opts, .{ .name = "a", .objc_source_bytes = 
    \\#import <Foundation/Foundation.h>
    \\@interface Foo : NSObject
    \\@end
    \\@implementation Foo
    \\@end
    });

    {
        const exe = addExecutable(b, opts, .{ .name = "main", .c_source_bytes = "int main() { return 0; }" });
        exe.root_module.linkSystemLibrary("a", .{});
        exe.root_module.linkFramework("Foundation", .{});
        exe.root_module.addLibraryPath(lib.getEmittedBinDirectory());

        const check = exe.checkObject();
        check.checkInSymtab();
        check.checkNotPresent("_OBJC_");
        test_step.dependOn(&check.step);

        const run = addRunArtifact(exe);
        run.expectExitCode(0);
        test_step.dependOn(&run.step);
    }

    {
        const exe = addExecutable(b, opts, .{ .name = "main2", .c_source_bytes = "int main() { return 0; }" });
        exe.root_module.linkSystemLibrary("a", .{});
        exe.root_module.linkFramework("Foundation", .{});
        exe.root_module.addLibraryPath(lib.getEmittedBinDirectory());
        exe.force_load_objc = true;

        const check = exe.checkObject();
        check.checkInSymtab();
        check.checkContains("_OBJC_");
        test_step.dependOn(&check.step);

        const run = addRunArtifact(exe);
        run.expectExitCode(0);
        test_step.dependOn(&run.step);
    }

    return test_step;
}

fn testObjcpp(b: *Build, opts: Options) *Step {
    const test_step = addTestStep(b, "objcpp", opts);

    const foo_h = foo_h: {
        const wf = WriteFile.create(b);
        break :foo_h wf.add("Foo.h",
            \\#import <Foundation/Foundation.h>
            \\@interface Foo : NSObject
            \\- (NSString *)name;
            \\@end
        );
    };

    const foo_o = addObject(b, opts, .{ .name = "foo", .objcpp_source_bytes = 
    \\#import "Foo.h"
    \\@implementation Foo
    \\- (NSString *)name
    \\{
    \\      NSString *str = [[NSString alloc] initWithFormat:@"Zig"];
    \\      return str;
    \\}
    \\@end
    });
    foo_o.root_module.addIncludePath(foo_h.dirname());
    foo_o.linkLibCpp();

    const exe = addExecutable(b, opts, .{ .name = "main", .objcpp_source_bytes = 
    \\#import "Foo.h"
    \\#import <assert.h>
    \\#include <iostream>
    \\int main(int argc, char *argv[])
    \\{
    \\  @autoreleasepool {
    \\      Foo *foo = [[Foo alloc] init];
    \\      NSString *result = [foo name];
    \\      std::cout << "Hello from C++ and " << [result UTF8String];
    \\      assert([result isEqualToString:@"Zig"]);
    \\      return 0;
    \\  }
    \\}
    });
    exe.root_module.addIncludePath(foo_h.dirname());
    exe.addObject(foo_o);
    exe.linkLibCpp();
    exe.root_module.linkFramework("Foundation", .{});

    const run = addRunArtifact(exe);
    run.expectStdOutEqual("Hello from C++ and Zig");
    test_step.dependOn(&run.step);

    return test_step;
}

fn testPagezeroSize(b: *Build, opts: Options) *Step {
    const test_step = addTestStep(b, "pagezero-size", opts);

    {
        const exe = addExecutable(b, opts, .{ .name = "main", .c_source_bytes = "int main () { return 0; }" });
        exe.pagezero_size = 0x4000;

        const check = exe.checkObject();
        check.checkInHeaders();
        check.checkExact("LC 0");
        check.checkExact("segname __PAGEZERO");
        check.checkExact("vmaddr 0");
        check.checkExact("vmsize 4000");
        check.checkInHeaders();
        check.checkExact("segname __TEXT");
        check.checkExact("vmaddr 4000");
        test_step.dependOn(&check.step);
    }

    {
        const exe = addExecutable(b, opts, .{ .name = "main", .c_source_bytes = "int main () { return 0; }" });
        exe.pagezero_size = 0;

        const check = exe.checkObject();
        check.checkInHeaders();
        check.checkExact("LC 0");
        check.checkExact("segname __TEXT");
        check.checkExact("vmaddr 0");
        test_step.dependOn(&check.step);
    }

    return test_step;
}

fn testReexportsZig(b: *Build, opts: Options) *Step {
    const test_step = addTestStep(b, "reexports-zig", opts);

    const lib = addStaticLibrary(b, opts, .{ .name = "a", .zig_source_bytes = 
    \\const x: i32 = 42;
    \\export fn foo() i32 {
    \\    return x;
    \\}
    \\comptime {
    \\    @export(foo, .{ .name = "bar", .linkage = .strong });
    \\}
    });

    const exe = addExecutable(b, opts, .{ .name = "main", .c_source_bytes = 
    \\extern int foo();
    \\extern int bar();
    \\int main() {
    \\  return bar() - foo();
    \\}
    });
    exe.linkLibrary(lib);

    const run = addRunArtifact(exe);
    run.expectExitCode(0);
    test_step.dependOn(&run.step);

    return test_step;
}

fn testRelocatable(b: *Build, opts: Options) *Step {
    const test_step = addTestStep(b, "relocatable", opts);

    const a_o = addObject(b, opts, .{ .name = "a", .cpp_source_bytes = 
    \\#include <stdexcept>
    \\int try_me() {
    \\  throw std::runtime_error("Oh no!");
    \\}
    });
    a_o.linkLibCpp();

    const b_o = addObject(b, opts, .{ .name = "b", .cpp_source_bytes = 
    \\extern int try_me();
    \\int try_again() {
    \\  return try_me();
    \\}
    });

    const main_o = addObject(b, opts, .{ .name = "main", .cpp_source_bytes = 
    \\#include <iostream>
    \\#include <stdexcept>
    \\extern int try_again();
    \\int main() {
    \\  try {
    \\    try_again();
    \\  } catch (const std::exception &e) {
    \\    std::cout << "exception=" << e.what();
    \\  }
    \\  return 0;
    \\}
    });
    main_o.linkLibCpp();

    const exp_stdout = "exception=Oh no!";

    {
        const c_o = addObject(b, opts, .{ .name = "c" });
        c_o.addObject(a_o);
        c_o.addObject(b_o);

        const exe = addExecutable(b, opts, .{ .name = "main1" });
        exe.addObject(main_o);
        exe.addObject(c_o);
        exe.linkLibCpp();

        const run = addRunArtifact(exe);
        run.expectStdOutEqual(exp_stdout);
        test_step.dependOn(&run.step);
    }

    {
        const d_o = addObject(b, opts, .{ .name = "d" });
        d_o.addObject(a_o);
        d_o.addObject(b_o);
        d_o.addObject(main_o);

        const exe = addExecutable(b, opts, .{ .name = "main2" });
        exe.addObject(d_o);
        exe.linkLibCpp();

        const run = addRunArtifact(exe);
        run.expectStdOutEqual(exp_stdout);
        test_step.dependOn(&run.step);
    }

    return test_step;
}

fn testRelocatableZig(b: *Build, opts: Options) *Step {
    const test_step = addTestStep(b, "relocatable-zig", opts);

    const a_o = addObject(b, opts, .{ .name = "a", .zig_source_bytes = 
    \\const std = @import("std");
    \\export var foo: i32 = 0;
    \\export fn incrFoo() void {
    \\    foo += 1;
    \\    std.debug.print("incrFoo={d}\n", .{foo});
    \\}
    });

    const b_o = addObject(b, opts, .{ .name = "b", .zig_source_bytes = 
    \\const std = @import("std");
    \\extern var foo: i32;
    \\export fn decrFoo() void {
    \\    foo -= 1;
    \\    std.debug.print("decrFoo={d}\n", .{foo});
    \\}
    });

    const main_o = addObject(b, opts, .{ .name = "main", .zig_source_bytes = 
    \\const std = @import("std");
    \\extern var foo: i32;
    \\extern fn incrFoo() void;
    \\extern fn decrFoo() void;
    \\pub fn main() void {
    \\    const init = foo;
    \\    incrFoo();
    \\    decrFoo();
    \\    if (init == foo) @panic("Oh no!");
    \\}
    });

    const c_o = addObject(b, opts, .{ .name = "c" });
    c_o.addObject(a_o);
    c_o.addObject(b_o);
    c_o.addObject(main_o);

    const exe = addExecutable(b, opts, .{ .name = "main" });
    exe.addObject(c_o);

    const run = addRunArtifact(exe);
    run.addCheck(.{ .expect_stderr_match = b.dupe("incrFoo=1") });
    run.addCheck(.{ .expect_stderr_match = b.dupe("decrFoo=0") });
    run.addCheck(.{ .expect_stderr_match = b.dupe("panic: Oh no!") });
    test_step.dependOn(&run.step);

    return test_step;
}

fn testSearchStrategy(b: *Build, opts: Options) *Step {
    const test_step = addTestStep(b, "search-strategy", opts);

    const obj = addObject(b, opts, .{ .name = "a", .c_source_bytes = 
    \\#include<stdio.h>
    \\char world[] = "world";
    \\char* hello() {
    \\  return "Hello";
    \\}
    });

    const liba = addStaticLibrary(b, opts, .{ .name = "a" });
    liba.addObject(obj);

    const dylib = addSharedLibrary(b, opts, .{ .name = "a" });
    dylib.addObject(obj);

    const main_o = addObject(b, opts, .{ .name = "main", .c_source_bytes = 
    \\#include<stdio.h>
    \\char* hello();
    \\extern char world[];
    \\int main() {
    \\  printf("%s %s", hello(), world);
    \\  return 0;
    \\}
    });

    {
        const exe = addExecutable(b, opts, .{ .name = "main" });
        exe.addObject(main_o);
        exe.root_module.linkSystemLibrary("a", .{ .use_pkg_config = .no, .search_strategy = .mode_first });
        exe.root_module.addLibraryPath(liba.getEmittedBinDirectory());
        exe.root_module.addLibraryPath(dylib.getEmittedBinDirectory());
        exe.root_module.addRPath(dylib.getEmittedBinDirectory());

        const run = addRunArtifact(exe);
        run.expectStdOutEqual("Hello world");
        test_step.dependOn(&run.step);

        const check = exe.checkObject();
        check.checkInHeaders();
        check.checkExact("cmd LOAD_DYLIB");
        check.checkContains("liba.dylib");
        test_step.dependOn(&check.step);
    }

    {
        const exe = addExecutable(b, opts, .{ .name = "main" });
        exe.addObject(main_o);
        exe.root_module.linkSystemLibrary("a", .{ .use_pkg_config = .no, .search_strategy = .paths_first });
        exe.root_module.addLibraryPath(liba.getEmittedBinDirectory());
        exe.root_module.addLibraryPath(dylib.getEmittedBinDirectory());
        exe.root_module.addRPath(dylib.getEmittedBinDirectory());

        const run = addRunArtifact(exe);
        run.expectStdOutEqual("Hello world");
        test_step.dependOn(&run.step);

        const check = exe.checkObject();
        check.checkInHeaders();
        check.checkExact("cmd LOAD_DYLIB");
        check.checkNotPresent("liba.dylib");
        test_step.dependOn(&check.step);
    }

    return test_step;
}

fn testSectionBoundarySymbols(b: *Build, opts: Options) *Step {
    const test_step = addTestStep(b, "section-boundary-symbols", opts);

    const obj1 = addObject(b, opts, .{
        .name = "obj1",
        .cpp_source_bytes =
        \\constexpr const char* MESSAGE __attribute__((used, section("__DATA_CONST,__message_ptr"))) = "codebase";
        ,
    });

    const main_o = addObject(b, opts, .{
        .name = "main",
        .zig_source_bytes =
        \\const std = @import("std");
        \\extern fn interop() ?[*:0]const u8;
        \\pub fn main() !void {
        \\    std.debug.print("All your {s} are belong to us.\n", .{
        \\        if (interop()) |ptr| std.mem.span(ptr) else "(null)",
        \\    });
        \\}
        ,
    });

    {
        const obj2 = addObject(b, opts, .{
            .name = "obj2",
            .cpp_source_bytes =
            \\extern const char* message_pointer __asm("section$start$__DATA_CONST$__message_ptr");
            \\extern "C" const char* interop() {
            \\  return message_pointer;
            \\}
            ,
        });

        const exe = addExecutable(b, opts, .{ .name = "test" });
        exe.addObject(obj1);
        exe.addObject(obj2);
        exe.addObject(main_o);

        const run = b.addRunArtifact(exe);
        run.skip_foreign_checks = true;
        run.expectStdErrEqual("All your codebase are belong to us.\n");
        test_step.dependOn(&run.step);

        const check = exe.checkObject();
        check.checkInSymtab();
        check.checkNotPresent("external section$start$__DATA_CONST$__message_ptr");
        test_step.dependOn(&check.step);
    }

    {
        const obj3 = addObject(b, opts, .{
            .name = "obj3",
            .cpp_source_bytes =
            \\extern const char* message_pointer __asm("section$start$__DATA_CONST$__not_present");
            \\extern "C" const char* interop() {
            \\  return message_pointer;
            \\}
            ,
        });

        const exe = addExecutable(b, opts, .{ .name = "test" });
        exe.addObject(obj1);
        exe.addObject(obj3);
        exe.addObject(main_o);

        const run = b.addRunArtifact(exe);
        run.skip_foreign_checks = true;
        run.expectStdErrEqual("All your (null) are belong to us.\n");
        test_step.dependOn(&run.step);

        const check = exe.checkObject();
        check.checkInSymtab();
        check.checkNotPresent("external section$start$__DATA_CONST$__not_present");
        test_step.dependOn(&check.step);
    }

    return test_step;
}

fn testSegmentBoundarySymbols(b: *Build, opts: Options) *Step {
    const test_step = addTestStep(b, "segment-boundary-symbols", opts);

    const obj1 = addObject(b, opts, .{ .name = "a", .cpp_source_bytes = 
    \\constexpr const char* MESSAGE __attribute__((used, section("__DATA_CONST_1,__message_ptr"))) = "codebase";
    });

    const main_o = addObject(b, opts, .{ .name = "main", .c_source_bytes = 
    \\#include <stdio.h>
    \\const char* interop();
    \\int main() {
    \\  printf("All your %s are belong to us.\n", interop());
    \\  return 0;
    \\}
    });

    {
        const obj2 = addObject(b, opts, .{ .name = "b", .cpp_source_bytes = 
        \\extern const char* message_pointer __asm("segment$start$__DATA_CONST_1");
        \\extern "C" const char* interop() {
        \\  return message_pointer;
        \\}
        });

        const exe = addExecutable(b, opts, .{ .name = "main" });
        exe.addObject(obj1);
        exe.addObject(obj2);
        exe.addObject(main_o);

        const run = addRunArtifact(exe);
        run.expectStdOutEqual("All your codebase are belong to us.\n");
        test_step.dependOn(&run.step);

        const check = exe.checkObject();
        check.checkInSymtab();
        check.checkNotPresent("external segment$start$__DATA_CONST_1");
        test_step.dependOn(&check.step);
    }

    {
        const obj2 = addObject(b, opts, .{ .name = "c", .cpp_source_bytes = 
        \\extern const char* message_pointer __asm("segment$start$__DATA_1");
        \\extern "C" const char* interop() {
        \\  return message_pointer;
        \\}
        });

        const exe = addExecutable(b, opts, .{ .name = "main2" });
        exe.addObject(obj1);
        exe.addObject(obj2);
        exe.addObject(main_o);

        const check = exe.checkObject();
        check.checkInHeaders();
        check.checkExact("cmd SEGMENT_64");
        check.checkExact("segname __DATA_1");
        check.checkExtract("vmsize {vmsize}");
        check.checkExtract("filesz {filesz}");
        check.checkComputeCompare("vmsize", .{ .op = .eq, .value = .{ .literal = 0 } });
        check.checkComputeCompare("filesz", .{ .op = .eq, .value = .{ .literal = 0 } });
        check.checkInSymtab();
        check.checkNotPresent("external segment$start$__DATA_1");
        test_step.dependOn(&check.step);
    }

    return test_step;
}

fn testStackSize(b: *Build, opts: Options) *Step {
    const test_step = addTestStep(b, "stack-size", opts);

    const exe = addExecutable(b, opts, .{ .name = "main", .c_source_bytes = "int main() { return 0; }" });
    exe.stack_size = 0x100000000;

    const run = addRunArtifact(exe);
    run.expectExitCode(0);
    test_step.dependOn(&run.step);

    const check = exe.checkObject();
    check.checkInHeaders();
    check.checkExact("cmd MAIN");
    check.checkExact("stacksize 100000000");
    test_step.dependOn(&check.step);

    return test_step;
}

fn testTbdv3(b: *Build, opts: Options) *Step {
    const test_step = addTestStep(b, "tbdv3", opts);

    const dylib = addSharedLibrary(b, opts, .{ .name = "a", .c_source_bytes = "int getFoo() { return 42; }" });

    const tbd = tbd: {
        const wf = WriteFile.create(b);
        break :tbd wf.add("liba.tbd",
            \\--- !tapi-tbd-v3
            \\archs:           [ arm64, x86_64 ]
            \\uuids:           [ 'arm64: DEADBEEF', 'x86_64: BEEFDEAD' ]
            \\platform:        macos
            \\install-name:    @rpath/liba.dylib
            \\current-version: 0
            \\exports:
            \\  - archs:           [ arm64, x86_64 ]
            \\    symbols:         [ _getFoo ]
        );
    };

    const exe = addExecutable(b, opts, .{ .name = "main", .c_source_bytes = 
    \\#include <stdio.h>
    \\int getFoo();
    \\int main() {
    \\  return getFoo() - 42;
    \\}
    });
    exe.root_module.linkSystemLibrary("a", .{});
    exe.root_module.addLibraryPath(tbd.dirname());
    exe.root_module.addRPath(dylib.getEmittedBinDirectory());

    const run = addRunArtifact(exe);
    run.expectExitCode(0);
    test_step.dependOn(&run.step);

    return test_step;
}

fn testTentative(b: *Build, opts: Options) *Step {
    const test_step = addTestStep(b, "tentative", opts);

    const exe = addExecutable(b, opts, .{ .name = "main" });
    addCSourceBytes(exe,
        \\int foo;
        \\int bar;
        \\int baz = 42;
    , &.{"-fcommon"});
    addCSourceBytes(exe,
        \\#include<stdio.h>
        \\int foo;
        \\int bar = 5;
        \\int baz;
        \\int main() {
        \\  printf("%d %d %d\n", foo, bar, baz);
        \\}
    , &.{"-fcommon"});

    const run = addRunArtifact(exe);
    run.expectStdOutEqual("0 5 42\n");
    test_step.dependOn(&run.step);

    return test_step;
}

fn testThunks(b: *Build, opts: Options) *Step {
    const test_step = addTestStep(b, "thunks", opts);

    const exe = addExecutable(b, opts, .{ .name = "main", .c_source_bytes = 
    \\#include <stdio.h>
    \\__attribute__((aligned(0x8000000))) int bar() {
    \\  return 42;
    \\}
    \\int foobar();
    \\int foo() {
    \\  return bar() - foobar();
    \\}
    \\__attribute__((aligned(0x8000000))) int foobar() {
    \\  return 42;
    \\}
    \\int main() {
    \\  printf("bar=%d, foo=%d, foobar=%d", bar(), foo(), foobar());
    \\  return foo();
    \\}
    });

    const run = addRunArtifact(exe);
    run.expectStdOutEqual("bar=42, foo=0, foobar=42");
    run.expectExitCode(0);
    test_step.dependOn(&run.step);

    return test_step;
}

fn testTls(b: *Build, opts: Options) *Step {
    const test_step = addTestStep(b, "tls", opts);

    const dylib = addSharedLibrary(b, opts, .{ .name = "a", .c_source_bytes = 
    \\_Thread_local int a;
    \\int getA() {
    \\  return a;
    \\}
    });

    const exe = addExecutable(b, opts, .{ .name = "main", .c_source_bytes = 
    \\#include<stdio.h>
    \\extern _Thread_local int a;
    \\extern int getA();
    \\int getA2() {
    \\  return a;
    \\}
    \\int main() {
    \\  a = 2;
    \\  printf("%d %d %d", a, getA(), getA2());
    \\  return 0;
    \\}
    });
    exe.root_module.linkSystemLibrary("a", .{});
    exe.root_module.addLibraryPath(dylib.getEmittedBinDirectory());
    exe.root_module.addRPath(dylib.getEmittedBinDirectory());

    const run = addRunArtifact(exe);
    run.expectStdOutEqual("2 2 2");
    test_step.dependOn(&run.step);

    return test_step;
}

// https://github.com/ziglang/zig/issues/19221
fn testTlsPointers(b: *Build, opts: Options) *Step {
    const test_step = addTestStep(b, "tls-pointers", opts);

    const foo_h = foo_h: {
        const wf = WriteFile.create(b);
        break :foo_h wf.add("foo.h",
            \\template<typename just4fun>
            \\struct Foo {
            \\
            \\public:
            \\  static int getVar() {
            \\  static int thread_local var = 0;
            \\  ++var;
            \\  return var;
            \\}
            \\};
        );
    };

    const bar_o = addObject(b, opts, .{ .name = "bar", .cpp_source_bytes = 
    \\#include "foo.h"
    \\int bar() {
    \\  int v1 = Foo<int>::getVar();
    \\  return v1;
    \\}
    });
    bar_o.root_module.addIncludePath(foo_h.dirname());
    bar_o.linkLibCpp();

    const baz_o = addObject(b, opts, .{ .name = "baz", .cpp_source_bytes = 
    \\#include "foo.h"
    \\int baz() {
    \\  int v1 = Foo<unsigned>::getVar();
    \\  return v1;
    \\}
    });
    baz_o.root_module.addIncludePath(foo_h.dirname());
    baz_o.linkLibCpp();

    const main_o = addObject(b, opts, .{ .name = "main", .cpp_source_bytes = 
    \\extern int bar();
    \\extern int baz();
    \\int main() {
    \\  int v1 = bar();
    \\  int v2 = baz();
    \\  return v1 != v2;
    \\}
    });
    main_o.root_module.addIncludePath(foo_h.dirname());
    main_o.linkLibCpp();

    const exe = addExecutable(b, opts, .{ .name = "main" });
    exe.addObject(bar_o);
    exe.addObject(baz_o);
    exe.addObject(main_o);
    exe.linkLibCpp();

    const run = addRunArtifact(exe);
    run.expectExitCode(0);
    test_step.dependOn(&run.step);

    return test_step;
}

fn testTlsLargeTbss(b: *Build, opts: Options) *Step {
    const test_step = addTestStep(b, "tls-large-tbss", opts);

    const exe = addExecutable(b, opts, .{ .name = "main", .c_source_bytes = 
    \\#include <stdio.h>
    \\_Thread_local int x[0x8000];
    \\_Thread_local int y[0x8000];
    \\int main() {
    \\  x[0] = 3;
    \\  x[0x7fff] = 5;
    \\  printf("%d %d %d %d %d %d\n", x[0], x[1], x[0x7fff], y[0], y[1], y[0x7fff]);
    \\}
    });

    const run = addRunArtifact(exe);
    run.expectStdOutEqual("3 0 5 0 0 0\n");
    test_step.dependOn(&run.step);

    return test_step;
}

fn testTwoLevelNamespace(b: *Build, opts: Options) *Step {
    const test_step = addTestStep(b, "two-level-namespace", opts);

    const liba = addSharedLibrary(b, opts, .{ .name = "a", .c_source_bytes = 
    \\#include <stdio.h>
    \\int foo = 1;
    \\int* ptr_to_foo = &foo;
    \\int getFoo() {
    \\  return foo;
    \\}
    \\void printInA() {
    \\  printf("liba: getFoo()=%d, ptr_to_foo=%d\n", getFoo(), *ptr_to_foo);
    \\}
    });

    {
        const check = liba.checkObject();
        check.checkInDyldLazyBind();
        check.checkNotPresent("(flat lookup) _getFoo");
        check.checkInIndirectSymtab();
        check.checkNotPresent("_getFoo");
        test_step.dependOn(&check.step);
    }

    const libb = addSharedLibrary(b, opts, .{ .name = "b", .c_source_bytes = 
    \\#include <stdio.h>
    \\int foo = 2;
    \\int* ptr_to_foo = &foo;
    \\int getFoo() {
    \\  return foo;
    \\}
    \\void printInB() {
    \\  printf("libb: getFoo()=%d, ptr_to_foo=%d\n", getFoo(), *ptr_to_foo);
    \\}
    });

    {
        const check = libb.checkObject();
        check.checkInDyldLazyBind();
        check.checkNotPresent("(flat lookup) _getFoo");
        check.checkInIndirectSymtab();
        check.checkNotPresent("_getFoo");
        test_step.dependOn(&check.step);
    }

    const main_o = addObject(b, opts, .{ .name = "main", .c_source_bytes = 
    \\#include <stdio.h>
    \\int getFoo();
    \\extern int* ptr_to_foo;
    \\void printInA();
    \\void printInB();
    \\int main() {
    \\  printf("main: getFoo()=%d, ptr_to_foo=%d\n", getFoo(), *ptr_to_foo);
    \\  printInA();
    \\  printInB();
    \\  return 0;
    \\}
    });

    {
        const exe = addExecutable(b, opts, .{ .name = "main1" });
        exe.addObject(main_o);
        exe.root_module.linkSystemLibrary("a", .{});
        exe.root_module.linkSystemLibrary("b", .{});
        exe.root_module.addLibraryPath(liba.getEmittedBinDirectory());
        exe.root_module.addLibraryPath(libb.getEmittedBinDirectory());
        exe.root_module.addRPath(liba.getEmittedBinDirectory());
        exe.root_module.addRPath(libb.getEmittedBinDirectory());

        const check = exe.checkObject();
        check.checkInSymtab();
        check.checkExact("(undefined) external _getFoo (from liba)");
        check.checkInSymtab();
        check.checkExact("(undefined) external _printInA (from liba)");
        check.checkInSymtab();
        check.checkExact("(undefined) external _printInB (from libb)");
        test_step.dependOn(&check.step);

        const run = addRunArtifact(exe);
        run.expectStdOutEqual(
            \\main: getFoo()=1, ptr_to_foo=1
            \\liba: getFoo()=1, ptr_to_foo=1
            \\libb: getFoo()=2, ptr_to_foo=2
            \\
        );
        test_step.dependOn(&run.step);
    }

    {
        const exe = addExecutable(b, opts, .{ .name = "main2" });
        exe.addObject(main_o);
        exe.root_module.linkSystemLibrary("b", .{});
        exe.root_module.linkSystemLibrary("a", .{});
        exe.root_module.addLibraryPath(liba.getEmittedBinDirectory());
        exe.root_module.addLibraryPath(libb.getEmittedBinDirectory());
        exe.root_module.addRPath(liba.getEmittedBinDirectory());
        exe.root_module.addRPath(libb.getEmittedBinDirectory());

        const check = exe.checkObject();
        check.checkInSymtab();
        check.checkExact("(undefined) external _getFoo (from libb)");
        check.checkInSymtab();
        check.checkExact("(undefined) external _printInA (from liba)");
        check.checkInSymtab();
        check.checkExact("(undefined) external _printInB (from libb)");
        test_step.dependOn(&check.step);

        const run = addRunArtifact(exe);
        run.expectStdOutEqual(
            \\main: getFoo()=2, ptr_to_foo=2
            \\liba: getFoo()=1, ptr_to_foo=1
            \\libb: getFoo()=2, ptr_to_foo=2
            \\
        );
        test_step.dependOn(&run.step);
    }

    return test_step;
}

fn testUndefinedFlag(b: *Build, opts: Options) *Step {
    const test_step = addTestStep(b, "undefined-flag", opts);

    const obj = addObject(b, opts, .{ .name = "a", .c_source_bytes = "int foo = 42;" });

    const lib = addStaticLibrary(b, opts, .{ .name = "a" });
    lib.addObject(obj);

    const main_o = addObject(b, opts, .{ .name = "main", .c_source_bytes = "int main() { return 0; }" });

    {
        const exe = addExecutable(b, opts, .{ .name = "main1" });
        exe.addObject(main_o);
        exe.linkLibrary(lib);
        exe.forceUndefinedSymbol("_foo");

        const run = addRunArtifact(exe);
        run.expectExitCode(0);
        test_step.dependOn(&run.step);

        const check = exe.checkObject();
        check.checkInSymtab();
        check.checkContains("_foo");
        test_step.dependOn(&check.step);
    }

    {
        const exe = addExecutable(b, opts, .{ .name = "main2" });
        exe.addObject(main_o);
        exe.linkLibrary(lib);
        exe.forceUndefinedSymbol("_foo");
        exe.link_gc_sections = true;

        const run = addRunArtifact(exe);
        run.expectExitCode(0);
        test_step.dependOn(&run.step);

        const check = exe.checkObject();
        check.checkInSymtab();
        check.checkContains("_foo");
        test_step.dependOn(&check.step);
    }

    {
        const exe = addExecutable(b, opts, .{ .name = "main3" });
        exe.addObject(main_o);
        exe.addObject(obj);

        const run = addRunArtifact(exe);
        run.expectExitCode(0);
        test_step.dependOn(&run.step);

        const check = exe.checkObject();
        check.checkInSymtab();
        check.checkContains("_foo");
        test_step.dependOn(&check.step);
    }

    {
        const exe = addExecutable(b, opts, .{ .name = "main4" });
        exe.addObject(main_o);
        exe.addObject(obj);
        exe.link_gc_sections = true;

        const run = addRunArtifact(exe);
        run.expectExitCode(0);
        test_step.dependOn(&run.step);

        const check = exe.checkObject();
        check.checkInSymtab();
        check.checkNotPresent("_foo");
        test_step.dependOn(&check.step);
    }

    return test_step;
}

fn testUnwindInfo(b: *Build, opts: Options) *Step {
    const test_step = addTestStep(b, "unwind-info", opts);

    const all_h = all_h: {
        const wf = WriteFile.create(b);
        break :all_h wf.add("all.h",
            \\#ifndef ALL
            \\#define ALL
            \\
            \\#include <cstddef>
            \\#include <string>
            \\#include <stdexcept>
            \\
            \\struct SimpleString {
            \\  SimpleString(size_t max_size);
            \\  ~SimpleString();
            \\
            \\  void print(const char* tag) const;
            \\  bool append_line(const char* x);
            \\
            \\private:
            \\  size_t max_size;
            \\  char* buffer;
            \\  size_t length;
            \\};
            \\
            \\struct SimpleStringOwner {
            \\  SimpleStringOwner(const char* x);
            \\  ~SimpleStringOwner();
            \\
            \\private:
            \\  SimpleString string;
            \\};
            \\
            \\class Error: public std::exception {
            \\public:
            \\  explicit Error(const char* msg) : msg{ msg } {}
            \\  virtual ~Error() noexcept {}
            \\  virtual const char* what() const noexcept {
            \\    return msg.c_str();
            \\  }
            \\
            \\protected:
            \\  std::string msg;
            \\};
            \\
            \\#endif
        );
    };

    const main_o = addObject(b, opts, .{ .name = "main", .cpp_source_bytes = 
    \\#include "all.h"
    \\#include <cstdio>
    \\
    \\void fn_c() {
    \\  SimpleStringOwner c{ "cccccccccc" };
    \\}
    \\
    \\void fn_b() {
    \\  SimpleStringOwner b{ "b" };
    \\  fn_c();
    \\}
    \\
    \\int main() {
    \\  try {
    \\    SimpleStringOwner a{ "a" };
    \\    fn_b();
    \\    SimpleStringOwner d{ "d" };
    \\  } catch (const Error& e) {
    \\    printf("Error: %s\n", e.what());
    \\  } catch(const std::exception& e) {
    \\    printf("Exception: %s\n", e.what());
    \\  }
    \\  return 0;
    \\}
    });
    main_o.root_module.addIncludePath(all_h.dirname());
    main_o.linkLibCpp();

    const simple_string_o = addObject(b, opts, .{ .name = "simple_string", .cpp_source_bytes = 
    \\#include "all.h"
    \\#include <cstdio>
    \\#include <cstring>
    \\
    \\SimpleString::SimpleString(size_t max_size)
    \\: max_size{ max_size }, length{} {
    \\  if (max_size == 0) {
    \\    throw Error{ "Max size must be at least 1." };
    \\  }
    \\  buffer = new char[max_size];
    \\  buffer[0] = 0;
    \\}
    \\
    \\SimpleString::~SimpleString() {
    \\  delete[] buffer;
    \\}
    \\
    \\void SimpleString::print(const char* tag) const {
    \\  printf("%s: %s", tag, buffer);
    \\}
    \\
    \\bool SimpleString::append_line(const char* x) {
    \\  const auto x_len = strlen(x);
    \\  if (x_len + length + 2 > max_size) return false;
    \\  std::strncpy(buffer + length, x, max_size - length);
    \\  length += x_len;
    \\  buffer[length++] = '\n';
    \\  buffer[length] = 0;
    \\  return true;
    \\}
    });
    simple_string_o.root_module.addIncludePath(all_h.dirname());
    simple_string_o.linkLibCpp();

    const simple_string_owner_o = addObject(b, opts, .{ .name = "simple_string_owner", .cpp_source_bytes = 
    \\#include "all.h"
    \\
    \\SimpleStringOwner::SimpleStringOwner(const char* x) : string{ 10 } {
    \\  if (!string.append_line(x)) {
    \\    throw Error{ "Not enough memory!" };
    \\  }
    \\  string.print("Constructed");
    \\}
    \\
    \\SimpleStringOwner::~SimpleStringOwner() {
    \\  string.print("About to destroy");
    \\}
    });
    simple_string_owner_o.root_module.addIncludePath(all_h.dirname());
    simple_string_owner_o.linkLibCpp();

    const exp_stdout =
        \\Constructed: a
        \\Constructed: b
        \\About to destroy: b
        \\About to destroy: a
        \\Error: Not enough memory!
        \\
    ;

    const exe = addExecutable(b, opts, .{ .name = "main" });
    exe.addObject(main_o);
    exe.addObject(simple_string_o);
    exe.addObject(simple_string_owner_o);
    exe.linkLibCpp();

    const run = addRunArtifact(exe);
    run.expectStdOutEqual(exp_stdout);
    test_step.dependOn(&run.step);

    const check = exe.checkObject();
    check.checkInSymtab();
    check.checkContains("(was private external) ___gxx_personality_v0");
    test_step.dependOn(&check.step);

    return test_step;
}

fn testUnwindInfoNoSubsectionsArm64(b: *Build, opts: Options) *Step {
    const test_step = addTestStep(b, "unwind-info-no-subsections-arm64", opts);

    const a_o = addObject(b, opts, .{ .name = "a", .asm_source_bytes = 
    \\.globl _foo
    \\.align 4
    \\_foo:
    \\  .cfi_startproc
    \\  stp     x29, x30, [sp, #-32]!
    \\  .cfi_def_cfa_offset 32
    \\  .cfi_offset w30, -24
    \\  .cfi_offset w29, -32
    \\  mov x29, sp
    \\  .cfi_def_cfa w29, 32
    \\  bl      _bar
    \\  ldp     x29, x30, [sp], #32
    \\  .cfi_restore w29
    \\  .cfi_restore w30
    \\  .cfi_def_cfa_offset 0
    \\  ret
    \\  .cfi_endproc
    \\
    \\.globl _bar
    \\.align 4
    \\_bar:
    \\  .cfi_startproc
    \\  sub     sp, sp, #32
    \\  .cfi_def_cfa_offset -32
    \\  stp     x29, x30, [sp, #16]
    \\  .cfi_offset w30, -24
    \\  .cfi_offset w29, -32
    \\  mov x29, sp
    \\  .cfi_def_cfa w29, 32
    \\  mov     w0, #4
    \\  ldp     x29, x30, [sp, #16]
    \\  .cfi_restore w29
    \\  .cfi_restore w30
    \\  add     sp, sp, #32
    \\  .cfi_def_cfa_offset 0
    \\  ret
    \\  .cfi_endproc
    });

    const exe = addExecutable(b, opts, .{ .name = "main", .c_source_bytes = 
    \\#include <stdio.h>
    \\int foo();
    \\int main() {
    \\  printf("%d\n", foo());
    \\  return 0;
    \\}
    });
    exe.addObject(a_o);

    const run = addRunArtifact(exe);
    run.expectStdOutEqual("4\n");
    test_step.dependOn(&run.step);

    return test_step;
}

fn testUnwindInfoNoSubsectionsX64(b: *Build, opts: Options) *Step {
    const test_step = addTestStep(b, "unwind-info-no-subsections-x64", opts);

    const a_o = addObject(b, opts, .{ .name = "a", .asm_source_bytes = 
    \\.globl _foo
    \\_foo:
    \\  .cfi_startproc
    \\  push    %rbp
    \\  .cfi_def_cfa_offset 8
    \\  .cfi_offset %rbp, -8
    \\  mov     %rsp, %rbp
    \\  .cfi_def_cfa_register %rbp
    \\  call    _bar
    \\  pop     %rbp
    \\  .cfi_restore %rbp
    \\  .cfi_def_cfa_offset 0
    \\  ret
    \\  .cfi_endproc
    \\
    \\.globl _bar
    \\_bar:
    \\  .cfi_startproc
    \\  push     %rbp
    \\  .cfi_def_cfa_offset 8
    \\  .cfi_offset %rbp, -8
    \\  mov     %rsp, %rbp
    \\  .cfi_def_cfa_register %rbp
    \\  mov     $4, %rax
    \\  pop     %rbp
    \\  .cfi_restore %rbp
    \\  .cfi_def_cfa_offset 0
    \\  ret
    \\  .cfi_endproc
    });

    const exe = addExecutable(b, opts, .{ .name = "main", .c_source_bytes = 
    \\#include <stdio.h>
    \\int foo();
    \\int main() {
    \\  printf("%d\n", foo());
    \\  return 0;
    \\}
    });
    exe.addObject(a_o);

    const run = addRunArtifact(exe);
    run.expectStdOutEqual("4\n");
    test_step.dependOn(&run.step);

    return test_step;
}

// Adapted from https://github.com/llvm/llvm-project/blob/main/lld/test/MachO/weak-binding.s
fn testWeakBind(b: *Build, opts: Options) *Step {
    const test_step = addTestStep(b, "weak-bind", opts);

    const lib = addSharedLibrary(b, opts, .{ .name = "foo", .asm_source_bytes = 
    \\.globl _weak_dysym
    \\.weak_definition _weak_dysym
    \\_weak_dysym:
    \\  .quad 0x1234
    \\
    \\.globl _weak_dysym_for_gotpcrel
    \\.weak_definition _weak_dysym_for_gotpcrel
    \\_weak_dysym_for_gotpcrel:
    \\  .quad 0x1234
    \\
    \\.globl _weak_dysym_fn
    \\.weak_definition _weak_dysym_fn
    \\_weak_dysym_fn:
    \\  ret
    \\
    \\.section __DATA,__thread_vars,thread_local_variables
    \\
    \\.globl _weak_dysym_tlv
    \\.weak_definition _weak_dysym_tlv
    \\_weak_dysym_tlv:
    \\  .quad 0x1234
    });

    {
        const check = lib.checkObject();
        check.checkInExports();
        check.checkExtract("[WEAK] {vmaddr1} _weak_dysym");
        check.checkExtract("[WEAK] {vmaddr2} _weak_dysym_for_gotpcrel");
        check.checkExtract("[WEAK] {vmaddr3} _weak_dysym_fn");
        check.checkExtract("[THREAD_LOCAL, WEAK] {vmaddr4} _weak_dysym_tlv");
        test_step.dependOn(&check.step);
    }

    const exe = addExecutable(b, opts, .{ .name = "main", .asm_source_bytes = 
    \\.globl _main, _weak_external, _weak_external_for_gotpcrel, _weak_external_fn
    \\.weak_definition _weak_external, _weak_external_for_gotpcrel, _weak_external_fn, _weak_internal, _weak_internal_for_gotpcrel, _weak_internal_fn
    \\
    \\_main:
    \\  mov _weak_dysym_for_gotpcrel@GOTPCREL(%rip), %rax
    \\  mov _weak_external_for_gotpcrel@GOTPCREL(%rip), %rax
    \\  mov _weak_internal_for_gotpcrel@GOTPCREL(%rip), %rax
    \\  mov _weak_tlv@TLVP(%rip), %rax
    \\  mov _weak_dysym_tlv@TLVP(%rip), %rax
    \\  mov _weak_internal_tlv@TLVP(%rip), %rax
    \\  callq _weak_dysym_fn
    \\  callq _weak_external_fn
    \\  callq _weak_internal_fn
    \\  mov $0, %rax
    \\  ret
    \\
    \\_weak_external:
    \\  .quad 0x1234
    \\
    \\_weak_external_for_gotpcrel:
    \\  .quad 0x1234
    \\
    \\_weak_external_fn:
    \\  ret
    \\
    \\_weak_internal:
    \\  .quad 0x1234
    \\
    \\_weak_internal_for_gotpcrel:
    \\  .quad 0x1234
    \\
    \\_weak_internal_fn:
    \\  ret
    \\
    \\.data
    \\  .quad _weak_dysym
    \\  .quad _weak_external + 2
    \\  .quad _weak_internal
    \\
    \\.tbss _weak_tlv$tlv$init, 4, 2
    \\.tbss _weak_internal_tlv$tlv$init, 4, 2
    \\
    \\.section __DATA,__thread_vars,thread_local_variables
    \\.globl _weak_tlv
    \\.weak_definition  _weak_tlv, _weak_internal_tlv
    \\
    \\_weak_tlv:
    \\  .quad __tlv_bootstrap
    \\  .quad 0
    \\  .quad _weak_tlv$tlv$init
    \\
    \\_weak_internal_tlv:
    \\  .quad __tlv_bootstrap
    \\  .quad 0
    \\  .quad _weak_internal_tlv$tlv$init
    });
    exe.linkLibrary(lib);

    {
        const check = exe.checkObject();

        check.checkInExports();
        check.checkExtract("[WEAK] {vmaddr1} _weak_external");
        check.checkExtract("[WEAK] {vmaddr2} _weak_external_for_gotpcrel");
        check.checkExtract("[WEAK] {vmaddr3} _weak_external_fn");
        check.checkExtract("[THREAD_LOCAL, WEAK] {vmaddr4} _weak_tlv");

        check.checkInDyldBind();
        check.checkContains("(libfoo.dylib) _weak_dysym_for_gotpcrel");
        check.checkContains("(libfoo.dylib) _weak_dysym_fn");
        check.checkContains("(libfoo.dylib) _weak_dysym");
        check.checkContains("(libfoo.dylib) _weak_dysym_tlv");

        check.checkInDyldWeakBind();
        check.checkContains("_weak_external_for_gotpcrel");
        check.checkContains("_weak_dysym_for_gotpcrel");
        check.checkContains("_weak_external_fn");
        check.checkContains("_weak_dysym_fn");
        check.checkContains("_weak_dysym");
        check.checkContains("_weak_external");
        check.checkContains("_weak_tlv");
        check.checkContains("_weak_dysym_tlv");

        test_step.dependOn(&check.step);
    }

    const run = addRunArtifact(exe);
    run.expectExitCode(0);
    test_step.dependOn(&run.step);

    return test_step;
}

fn testWeakFramework(b: *Build, opts: Options) *Step {
    const test_step = addTestStep(b, "weak-framework", opts);

    const exe = addExecutable(b, opts, .{ .name = "main", .c_source_bytes = "int main() { return 0; }" });
    exe.root_module.linkFramework("Cocoa", .{ .weak = true });

    const run = addRunArtifact(exe);
    run.expectExitCode(0);
    test_step.dependOn(&run.step);

    const check = exe.checkObject();
    check.checkInHeaders();
    check.checkExact("cmd LOAD_WEAK_DYLIB");
    check.checkContains("Cocoa");
    test_step.dependOn(&check.step);

    return test_step;
}

fn testWeakLibrary(b: *Build, opts: Options) *Step {
    const test_step = addTestStep(b, "weak-library", opts);

    const dylib = addSharedLibrary(b, opts, .{ .name = "a", .c_source_bytes = 
    \\#include<stdio.h>
    \\int a = 42;
    \\const char* asStr() {
    \\  static char str[3];
    \\  sprintf(str, "%d", 42);
    \\  return str;
    \\}
    });

    const exe = addExecutable(b, opts, .{ .name = "main", .c_source_bytes = 
    \\#include<stdio.h>
    \\extern int a;
    \\extern const char* asStr();
    \\int main() {
    \\  printf("%d %s", a, asStr());
    \\  return 0;
    \\}
    });
    exe.root_module.linkSystemLibrary("a", .{ .weak = true });
    exe.root_module.addLibraryPath(dylib.getEmittedBinDirectory());
    exe.root_module.addRPath(dylib.getEmittedBinDirectory());

    const check = exe.checkObject();
    check.checkInHeaders();
    check.checkExact("cmd LOAD_WEAK_DYLIB");
    check.checkContains("liba.dylib");
    check.checkInSymtab();
    check.checkExact("(undefined) weakref external _a (from liba)");
    check.checkInSymtab();
    check.checkExact("(undefined) weakref external _asStr (from liba)");
    test_step.dependOn(&check.step);

    const run = addRunArtifact(exe);
    run.expectStdOutEqual("42 42");
    test_step.dependOn(&run.step);

    return test_step;
}

fn testWeakRef(b: *Build, opts: Options) *Step {
    const test_step = addTestStep(b, "weak-ref", opts);

    const exe = addExecutable(b, opts, .{ .name = "main", .c_source_bytes = 
    \\#include <stdio.h>
    \\#include <sys/_types/_fd_def.h>
    \\int main(int argc, char** argv) {
    \\    printf("__darwin_check_fd_set_overflow: %p\n", __darwin_check_fd_set_overflow);
    \\}
    });

    const check = exe.checkObject();
    check.checkInSymtab();
    check.checkExact("(undefined) weakref external ___darwin_check_fd_set_overflow (from libSystem.B)");
    test_step.dependOn(&check.step);

    return test_step;
}

fn addTestStep(b: *Build, comptime prefix: []const u8, opts: Options) *Step {
    return link.addTestStep(b, "" ++ prefix, opts);
}

const builtin = @import("builtin");
const addAsmSourceBytes = link.addAsmSourceBytes;
const addCSourceBytes = link.addCSourceBytes;
const addRunArtifact = link.addRunArtifact;
const addObject = link.addObject;
const addExecutable = link.addExecutable;
const addStaticLibrary = link.addStaticLibrary;
const addSharedLibrary = link.addSharedLibrary;
const expectLinkErrors = link.expectLinkErrors;
const link = @import("link.zig");
const std = @import("std");

const Build = std.Build;
const BuildOptions = link.BuildOptions;
const Compile = Step.Compile;
const Options = link.Options;
const Step = Build.Step;
const WriteFile = Step.WriteFile;

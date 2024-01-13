//! Here we test our MachO linker for correctness and functionality.
//! TODO migrate standalone tests from test/link/macho/* to here.

pub fn testAll(b: *Build, build_opts: BuildOptions) *Step {
    const macho_step = b.step("test-macho", "Run MachO tests");

    const default_target = b.resolveTargetQuery(.{
        .os_tag = .macos,
    });
    const x86_64_target = b.resolveTargetQuery(.{
        .cpu_arch = .x86_64,
        .os_tag = .macos,
    });

    macho_step.dependOn(testDeadStrip(b, .{ .target = default_target }));
    macho_step.dependOn(testEntryPointDylib(b, .{ .target = default_target }));
    macho_step.dependOn(testHeaderWeakFlags(b, .{ .target = default_target }));
    macho_step.dependOn(testHelloC(b, .{ .target = default_target }));
    macho_step.dependOn(testHelloZig(b, .{ .target = default_target }));
    macho_step.dependOn(testLargeBss(b, .{ .target = default_target }));
    macho_step.dependOn(testMhExecuteHeader(b, .{ .target = default_target }));
    macho_step.dependOn(testSectionBoundarySymbols(b, .{ .target = default_target }));
    macho_step.dependOn(testSegmentBoundarySymbols(b, .{ .target = default_target }));
    macho_step.dependOn(testWeakBind(b, .{ .target = x86_64_target }));

    // Tests requiring symlinks when tested on Windows
    if (build_opts.has_symlinks_windows) {
        macho_step.dependOn(testNeededLibrary(b, .{ .target = default_target }));

        // Tests requiring presence of macOS SDK in system path
        if (build_opts.has_macos_sdk) {
            macho_step.dependOn(testHeaderpad(b, .{ .target = b.host }));
            macho_step.dependOn(testNeededFramework(b, .{ .target = b.host }));
        }
    }

    return macho_step;
}

fn testDeadStrip(b: *Build, opts: Options) *Step {
    const test_step = addTestStep(b, "macho-dead-strip", opts);

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

fn testEntryPointDylib(b: *Build, opts: Options) *Step {
    const test_step = addTestStep(b, "macho-entry-point-dylib", opts);

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
    const test_step = addTestStep(b, "macho-headerpad", opts);

    const addExe = struct {
        fn addExe(bb: *Build, o: Options, name: []const u8) *Compile {
            const exe = addExecutable(bb, o, .{
                .name = name,
                .c_source_bytes = "int main() { return 0; }",
            });
            exe.linkFramework("CoreFoundation");
            exe.linkFramework("Foundation");
            exe.linkFramework("Cocoa");
            exe.linkFramework("CoreGraphics");
            exe.linkFramework("CoreHaptics");
            exe.linkFramework("CoreAudio");
            exe.linkFramework("AVFoundation");
            exe.linkFramework("CoreImage");
            exe.linkFramework("CoreLocation");
            exe.linkFramework("CoreML");
            exe.linkFramework("CoreVideo");
            exe.linkFramework("CoreText");
            exe.linkFramework("CryptoKit");
            exe.linkFramework("GameKit");
            exe.linkFramework("SwiftUI");
            exe.linkFramework("StoreKit");
            exe.linkFramework("SpriteKit");
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
    const test_step = addTestStep(b, "macho-header-weak-flags", opts);

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
    const test_step = addTestStep(b, "macho-hello-c", opts);

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
    const test_step = addTestStep(b, "macho-hello-zig", opts);

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
    const test_step = addTestStep(b, "macho-large-bss", opts);

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

fn testMhExecuteHeader(b: *Build, opts: Options) *Step {
    const test_step = addTestStep(b, "macho-mh-execute-header", opts);

    const exe = addExecutable(b, opts, .{ .name = "main", .c_source_bytes = "int main() { return 0; }" });

    const check = exe.checkObject();
    check.checkInSymtab();
    check.checkContains("[referenced dynamically] external __mh_execute_header");
    test_step.dependOn(&check.step);

    return test_step;
}

fn testNeededFramework(b: *Build, opts: Options) *Step {
    const test_step = addTestStep(b, "macho-needed-framework", opts);

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
    const test_step = addTestStep(b, "macho-needed-library", opts);

    const dylib = addSharedLibrary(b, opts, .{ .name = "a", .c_source_bytes = "int a = 42;" });

    const exe = addExecutable(b, opts, .{ .name = "main", .c_source_bytes = "int main() { return 0; }" });
    exe.root_module.linkSystemLibrary("a", .{ .needed = true });
    exe.addLibraryPath(dylib.getEmittedBinDirectory());
    exe.addRPath(dylib.getEmittedBinDirectory());
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

fn testSectionBoundarySymbols(b: *Build, opts: Options) *Step {
    const test_step = addTestStep(b, "macho-section-boundary-symbols", opts);

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
    const test_step = addTestStep(b, "macho-segment-boundary-symbols", opts);

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

// Adapted from https://github.com/llvm/llvm-project/blob/main/lld/test/MachO/weak-binding.s
fn testWeakBind(b: *Build, opts: Options) *Step {
    const test_step = addTestStep(b, "macho-weak-bind", opts);

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

fn addTestStep(b: *Build, comptime prefix: []const u8, opts: Options) *Step {
    return link.addTestStep(b, "macho-" ++ prefix, opts);
}

const addAsmSourceBytes = link.addAsmSourceBytes;
const addCSourceBytes = link.addCSourceBytes;
const addRunArtifact = link.addRunArtifact;
const addObject = link.addObject;
const addExecutable = link.addExecutable;
const addSharedLibrary = link.addSharedLibrary;
const expectLinkErrors = link.expectLinkErrors;
const link = @import("link.zig");
const std = @import("std");

const Build = std.Build;
const BuildOptions = link.BuildOptions;
const Compile = Step.Compile;
const Options = link.Options;
const Step = Build.Step;

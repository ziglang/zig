//! Here we test our MachO linker for correctness and functionality.
//! TODO migrate standalone tests from test/link/macho/* to here.

pub fn testAll(b: *Build, build_opts: BuildOptions) *Step {
    const macho_step = b.step("test-macho", "Run MachO tests");

    const default_target = b.resolveTargetQuery(.{
        .os_tag = .macos,
    });

    macho_step.dependOn(testDeadStrip(b, .{ .target = default_target }));
    macho_step.dependOn(testEntryPointDylib(b, .{ .target = default_target }));
    macho_step.dependOn(testMhExecuteHeader(b, .{ .target = default_target }));
    macho_step.dependOn(testSectionBoundarySymbols(b, .{ .target = default_target }));
    macho_step.dependOn(testSegmentBoundarySymbols(b, .{ .target = default_target }));

    // Tests requiring symlinks when tested on Windows
    if (build_opts.has_symlinks_windows) {
        macho_step.dependOn(testNeededLibrary(b, .{ .target = default_target }));

        // Tests requiring presence of macOS SDK in system path
        if (build_opts.has_macos_sdk) {
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

fn addTestStep(b: *Build, comptime prefix: []const u8, opts: Options) *Step {
    return link.addTestStep(b, "macho-" ++ prefix, opts);
}

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
const Options = link.Options;
const Step = Build.Step;

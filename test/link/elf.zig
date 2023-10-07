//! Here we test our ELF linker for correctness and functionality.
//! Currently, we support linking x86_64 Linux, but in the future we
//! will progressively relax those to exercise more combinations.

pub fn build(b: *Build) void {
    const elf_step = b.step("test-elf", "Run ELF tests");
    b.default_step = elf_step;

    const musl_target = CrossTarget{
        .cpu_arch = .x86_64, // TODO relax this once ELF linker is able to handle other archs
        .os_tag = .linux,
        .abi = .musl,
    };
    const glibc_target = CrossTarget{
        .cpu_arch = .x86_64,
        .os_tag = .linux,
        .abi = .gnu,
    };

    var dynamic_linker: ?[]const u8 = null;
    if (std.zig.system.NativeTargetInfo.detect(.{})) |host| blk: {
        if (host.target.cpu.arch != glibc_target.cpu_arch.? or
            host.target.os.tag != glibc_target.os_tag.? or
            host.target.abi != glibc_target.abi.?) break :blk;
        if (host.dynamic_linker.get()) |path| {
            dynamic_linker = b.dupe(path);
        }
    } else |_| {}

    // Exercise linker with self-hosted backend (no LLVM)
    // elf_step.dependOn(testLinkingZig(b, .{ .use_llvm = false }));

    // Exercise linker with LLVM backend
    elf_step.dependOn(testAbsSymbols(b, .{ .target = musl_target }));
    elf_step.dependOn(testCommonSymbols(b, .{ .target = musl_target }));
    elf_step.dependOn(testCommonSymbolsInArchive(b, .{ .target = musl_target }));
    elf_step.dependOn(testEmptyObject(b, .{ .target = musl_target }));
    elf_step.dependOn(testEntryPoint(b, .{ .target = musl_target }));
    elf_step.dependOn(testGcSections(b, .{ .target = musl_target }));
    elf_step.dependOn(testLinkingC(b, .{ .target = musl_target }));
    elf_step.dependOn(testLinkingCpp(b, .{ .target = musl_target }));
    elf_step.dependOn(testLinkingZig(b, .{ .target = musl_target }));
    elf_step.dependOn(testTlsStatic(b, .{ .target = musl_target }));

    elf_step.dependOn(testAsNeeded(b, .{ .target = glibc_target, .dynamic_linker = dynamic_linker }));
    elf_step.dependOn(testCanonicalPlt(b, .{ .target = glibc_target, .dynamic_linker = dynamic_linker }));
    elf_step.dependOn(testCopyrel(b, .{ .target = glibc_target, .dynamic_linker = dynamic_linker }));
    elf_step.dependOn(testCopyrelAlias(b, .{ .target = glibc_target, .dynamic_linker = dynamic_linker }));
    elf_step.dependOn(testCopyrelAlignment(b, .{ .target = glibc_target, .dynamic_linker = dynamic_linker }));
    elf_step.dependOn(testDsoPlt(b, .{ .target = glibc_target, .dynamic_linker = dynamic_linker }));
    elf_step.dependOn(testDsoUndef(b, .{ .target = glibc_target, .dynamic_linker = dynamic_linker }));
    elf_step.dependOn(testExportDynamic(b, .{ .target = glibc_target, .dynamic_linker = dynamic_linker }));
    elf_step.dependOn(testExportSymbolsFromExe(b, .{ .target = glibc_target, .dynamic_linker = dynamic_linker }));
    elf_step.dependOn(testLargeAlignmentDso(b, .{ .target = glibc_target, .dynamic_linker = dynamic_linker }));
    elf_step.dependOn(testLargeAlignmentExe(b, .{ .target = glibc_target, .dynamic_linker = dynamic_linker }));
}

fn testAbsSymbols(b: *Build, opts: Options) *Step {
    const test_step = addTestStep(b, "abs-symbols", opts);

    const obj = addObject(b, "obj", opts);
    addAsmSourceBytes(obj,
        \\.globl foo
        \\foo = 0x800008
    );

    const exe = addExecutable(b, "test", opts);
    addCSourceBytes(exe,
        \\#include <signal.h>
        \\#include <stdio.h>
        \\#include <stdlib.h>
        \\#include <ucontext.h>
        \\#include <assert.h>
        \\void handler(int signum, siginfo_t *info, void *ptr) {
        \\  assert((size_t)info->si_addr == 0x800008);
        \\  exit(0);
        \\}
        \\extern int foo;
        \\int main() {
        \\  struct sigaction act;
        \\  act.sa_flags = SA_SIGINFO | SA_RESETHAND;
        \\  act.sa_sigaction = handler;
        \\  sigemptyset(&act.sa_mask);
        \\  sigaction(SIGSEGV, &act, 0);
        \\  foo = 5;
        \\  return 0;
        \\}
    , &.{});
    exe.addObject(obj);
    exe.linkLibC();

    const run = addRunArtifact(exe);
    test_step.dependOn(&run.step);

    return test_step;
}

fn testAsNeeded(b: *Build, opts: Options) *Step {
    const test_step = addTestStep(b, "as-needed", opts);

    const main_o = addObject(b, "main", opts);
    addCSourceBytes(main_o,
        \\#include <stdio.h>
        \\int baz();
        \\int main() {
        \\  printf("%d\n", baz());
        \\  return 0;
        \\}
    , &.{});
    main_o.linkLibC();

    const libfoo = addSharedLibrary(b, "foo", opts);
    addCSourceBytes(libfoo, "int foo() { return 42; }", &.{"-fPIC"});

    const libbar = addSharedLibrary(b, "bar", opts);
    addCSourceBytes(libbar, "int bar() { return 42; }", &.{"-fPIC"});

    const libbaz = addSharedLibrary(b, "baz", opts);
    addCSourceBytes(libbaz,
        \\int foo();
        \\int baz() { return foo(); }
    , &.{"-fPIC"});

    {
        const exe = addExecutable(b, "test", opts);
        exe.addObject(main_o);
        exe.linkSystemLibrary2("foo", .{ .needed = true });
        exe.addLibraryPath(libfoo.getEmittedBinDirectory());
        exe.addRPath(libfoo.getEmittedBinDirectory());
        exe.linkSystemLibrary2("bar", .{ .needed = true });
        exe.addLibraryPath(libbar.getEmittedBinDirectory());
        exe.addRPath(libbar.getEmittedBinDirectory());
        exe.linkSystemLibrary2("baz", .{ .needed = true });
        exe.addLibraryPath(libbaz.getEmittedBinDirectory());
        exe.addRPath(libbaz.getEmittedBinDirectory());
        exe.linkLibC();

        const run = addRunArtifact(exe);
        run.expectStdOutEqual("42\n");
        test_step.dependOn(&run.step);

        const check = exe.checkObject();
        check.checkInDynamicSection();
        check.checkExact("NEEDED libfoo.so");
        check.checkExact("NEEDED libbar.so");
        check.checkExact("NEEDED libbaz.so");
        test_step.dependOn(&check.step);
    }

    {
        const exe = addExecutable(b, "test", opts);
        exe.addObject(main_o);
        exe.linkSystemLibrary2("foo", .{ .needed = false });
        exe.addLibraryPath(libfoo.getEmittedBinDirectory());
        exe.addRPath(libfoo.getEmittedBinDirectory());
        exe.linkSystemLibrary2("bar", .{ .needed = false });
        exe.addLibraryPath(libbar.getEmittedBinDirectory());
        exe.addRPath(libbar.getEmittedBinDirectory());
        exe.linkSystemLibrary2("baz", .{ .needed = false });
        exe.addLibraryPath(libbaz.getEmittedBinDirectory());
        exe.addRPath(libbaz.getEmittedBinDirectory());
        exe.linkLibC();

        const run = addRunArtifact(exe);
        run.expectStdOutEqual("42\n");
        test_step.dependOn(&run.step);

        const check = exe.checkObject();
        check.checkInDynamicSection();
        check.checkNotPresent("NEEDED libbar.so");
        check.checkInDynamicSection();
        check.checkExact("NEEDED libfoo.so");
        check.checkExact("NEEDED libbaz.so");
        test_step.dependOn(&check.step);
    }

    return test_step;
}

fn testCanonicalPlt(b: *Build, opts: Options) *Step {
    const test_step = addTestStep(b, "canonical-plt", opts);

    const dso = addSharedLibrary(b, "a", opts);
    addCSourceBytes(dso,
        \\void *foo() {
        \\  return foo;
        \\}
        \\void *bar() {
        \\  return bar;
        \\}
    , &.{"-fPIC"});

    const b_o = addObject(b, "obj", opts);
    addCSourceBytes(b_o,
        \\void *bar();
        \\void *baz() {
        \\  return bar;
        \\}
    , &.{"-fPIC"});

    const main_o = addObject(b, "main", opts);
    addCSourceBytes(main_o,
        \\#include <assert.h>
        \\void *foo();
        \\void *bar();
        \\void *baz();
        \\int main() {
        \\  assert(foo == foo());
        \\  assert(bar == bar());
        \\  assert(bar == baz());
        \\  return 0;
        \\}
    , &.{"-fno-PIC"});
    main_o.linkLibC();

    const exe = addExecutable(b, "main", opts);
    exe.addObject(main_o);
    exe.addObject(b_o);
    exe.linkLibrary(dso);
    exe.linkLibC();
    exe.pie = false;

    const run = addRunArtifact(exe);
    run.expectExitCode(0);
    test_step.dependOn(&run.step);

    return test_step;
}

fn testCommonSymbols(b: *Build, opts: Options) *Step {
    const test_step = addTestStep(b, "common-symbols", opts);

    const exe = addExecutable(b, "test", opts);
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
    exe.linkLibC();

    const run = addRunArtifact(exe);
    run.expectStdOutEqual("0 5 42\n");
    test_step.dependOn(&run.step);

    return test_step;
}

fn testCommonSymbolsInArchive(b: *Build, opts: Options) *Step {
    const test_step = addTestStep(b, "common-symbols-in-archive", opts);

    const a_o = addObject(b, "a", opts);
    addCSourceBytes(a_o,
        \\#include <stdio.h>
        \\int foo;
        \\int bar;
        \\extern int baz;
        \\__attribute__((weak)) int two();
        \\int main() {
        \\  printf("%d %d %d %d\n", foo, bar, baz, two ? two() : -1);
        \\}
    , &.{"-fcommon"});
    a_o.linkLibC();

    const b_o = addObject(b, "b", opts);
    addCSourceBytes(b_o, "int foo = 5;", &.{"-fcommon"});

    {
        const c_o = addObject(b, "c", opts);
        addCSourceBytes(c_o,
            \\int bar;
            \\int two() { return 2; }
        , &.{"-fcommon"});

        const d_o = addObject(b, "d", opts);
        addCSourceBytes(d_o, "int baz;", &.{"-fcommon"});

        const lib = addStaticLibrary(b, "lib", opts);
        lib.addObject(b_o);
        lib.addObject(c_o);
        lib.addObject(d_o);

        const exe = addExecutable(b, "test", opts);
        exe.addObject(a_o);
        exe.linkLibrary(lib);
        exe.linkLibC();

        const run = addRunArtifact(exe);
        run.expectStdOutEqual("5 0 0 -1\n");
        test_step.dependOn(&run.step);
    }

    {
        const e_o = addObject(b, "e", opts);
        addCSourceBytes(e_o,
            \\int bar = 0;
            \\int baz = 7;
            \\int two() { return 2; }
        , &.{"-fcommon"});

        const lib = addStaticLibrary(b, "lib", opts);
        lib.addObject(b_o);
        lib.addObject(e_o);

        const exe = addExecutable(b, "test", opts);
        exe.addObject(a_o);
        exe.linkLibrary(lib);
        exe.linkLibC();

        const run = addRunArtifact(exe);
        run.expectStdOutEqual("5 0 7 2\n");
        test_step.dependOn(&run.step);
    }

    return test_step;
}

fn testCopyrel(b: *Build, opts: Options) *Step {
    const test_step = addTestStep(b, "copyrel", opts);

    const dso = addSharedLibrary(b, "a", opts);
    addCSourceBytes(dso,
        \\int foo = 3;
        \\int bar = 5;
    , &.{"-fPIC"});

    const exe = addExecutable(b, "main", opts);
    addCSourceBytes(exe,
        \\#include<stdio.h>
        \\extern int foo, bar;
        \\int main() {
        \\  printf("%d %d\n", foo, bar);
        \\  return 0;
        \\}
    , &.{});
    exe.linkLibrary(dso);
    exe.linkLibC();

    const run = addRunArtifact(exe);
    run.expectStdOutEqual("3 5\n");
    test_step.dependOn(&run.step);

    return test_step;
}

fn testCopyrelAlias(b: *Build, opts: Options) *Step {
    const test_step = addTestStep(b, "copyrel-alias", opts);

    const dso = addSharedLibrary(b, "a", opts);
    addCSourceBytes(dso,
        \\int bruh = 31;
        \\int foo = 42;
        \\extern int bar __attribute__((alias("foo")));
        \\extern int baz __attribute__((alias("foo")));
    , &.{"-fPIC"});

    const exe = addExecutable(b, "main", opts);
    addCSourceBytes(exe,
        \\#include<stdio.h>
        \\extern int foo;
        \\extern int *get_bar();
        \\int main() {
        \\  printf("%d %d %d\n", foo, *get_bar(), &foo == get_bar());
        \\  return 0;
        \\}
    , &.{"-fno-PIC"});
    addCSourceBytes(exe,
        \\extern int bar;
        \\int *get_bar() { return &bar; }
    , &.{"-fno-PIC"});
    exe.linkLibrary(dso);
    exe.linkLibC();
    exe.pie = false;

    const run = addRunArtifact(exe);
    run.expectStdOutEqual("42 42 1\n");
    test_step.dependOn(&run.step);

    return test_step;
}

fn testCopyrelAlignment(b: *Build, opts: Options) *Step {
    const test_step = addTestStep(b, "copyrel-alignment", opts);

    const a_so = addSharedLibrary(b, "a", opts);
    addCSourceBytes(a_so, "__attribute__((aligned(32))) int foo = 5;", &.{"-fPIC"});

    const b_so = addSharedLibrary(b, "b", opts);
    addCSourceBytes(b_so, "__attribute__((aligned(8))) int foo = 5;", &.{"-fPIC"});

    const c_so = addSharedLibrary(b, "c", opts);
    addCSourceBytes(c_so, "__attribute__((aligned(256))) int foo = 5;", &.{"-fPIC"});

    const obj = addObject(b, "main", opts);
    addCSourceBytes(obj,
        \\#include <stdio.h>
        \\extern int foo;
        \\int main() { printf("%d\n", foo); }
    , &.{"-fno-PIE"});
    obj.linkLibC();

    const exp_stdout = "5\n";

    {
        const exe = addExecutable(b, "main", opts);
        exe.addObject(obj);
        exe.linkLibrary(a_so);
        exe.linkLibC();
        exe.pie = false;

        const run = addRunArtifact(exe);
        run.expectStdOutEqual(exp_stdout);
        test_step.dependOn(&run.step);

        const check = exe.checkObject();
        check.checkStart();
        check.checkExact("section headers");
        check.checkExact("name .copyrel");
        check.checkExact("addralign 20");
        test_step.dependOn(&check.step);
    }

    {
        const exe = addExecutable(b, "main", opts);
        exe.addObject(obj);
        exe.linkLibrary(b_so);
        exe.linkLibC();
        exe.pie = false;

        const run = addRunArtifact(exe);
        run.expectStdOutEqual(exp_stdout);
        test_step.dependOn(&run.step);

        const check = exe.checkObject();
        check.checkStart();
        check.checkExact("section headers");
        check.checkExact("name .copyrel");
        check.checkExact("addralign 8");
        test_step.dependOn(&check.step);
    }

    {
        const exe = addExecutable(b, "main", opts);
        exe.addObject(obj);
        exe.linkLibrary(c_so);
        exe.linkLibC();
        exe.pie = false;

        const run = addRunArtifact(exe);
        run.expectStdOutEqual(exp_stdout);
        test_step.dependOn(&run.step);

        const check = exe.checkObject();
        check.checkStart();
        check.checkExact("section headers");
        check.checkExact("name .copyrel");
        check.checkExact("addralign 100");
        test_step.dependOn(&check.step);
    }

    return test_step;
}

fn testDsoPlt(b: *Build, opts: Options) *Step {
    const test_step = addTestStep(b, "dso-plt", opts);

    const dso = addSharedLibrary(b, "dso", opts);
    addCSourceBytes(dso,
        \\#include<stdio.h>
        \\void world() {
        \\  printf("world\n");
        \\}
        \\void real_hello() {
        \\  printf("Hello ");
        \\  world();
        \\}
        \\void hello() {
        \\  real_hello();
        \\}
    , &.{"-fPIC"});
    dso.linkLibC();

    const exe = addExecutable(b, "test", opts);
    addCSourceBytes(exe,
        \\#include<stdio.h>
        \\void world() {
        \\  printf("WORLD\n");
        \\}
        \\void hello();
        \\int main() {
        \\  hello();
        \\}
    , &.{});
    exe.linkLibrary(dso);
    exe.linkLibC();

    const run = addRunArtifact(exe);
    run.expectStdOutEqual("Hello WORLD\n");
    test_step.dependOn(&run.step);

    return test_step;
}

fn testDsoUndef(b: *Build, opts: Options) *Step {
    const test_step = addTestStep(b, "dso-undef", opts);

    const dso = addSharedLibrary(b, "dso", opts);
    addCSourceBytes(dso,
        \\extern int foo;
        \\int bar = 5;
        \\int baz() { return foo; }
    , &.{"-fPIC"});
    dso.linkLibC();

    const obj = addObject(b, "obj", opts);
    addCSourceBytes(obj, "int foo = 3;", &.{});

    const lib = addStaticLibrary(b, "lib", opts);
    lib.addObject(obj);

    const exe = addExecutable(b, "test", opts);
    exe.linkLibrary(dso);
    exe.linkLibrary(lib);
    addCSourceBytes(exe,
        \\extern int bar;
        \\int main() {
        \\  return bar - 5;
        \\}
    , &.{});
    exe.linkLibC();

    const run = addRunArtifact(exe);
    run.expectExitCode(0);
    test_step.dependOn(&run.step);

    const check = exe.checkObject();
    check.checkInDynamicSymtab();
    check.checkContains("foo");
    test_step.dependOn(&check.step);

    return test_step;
}

fn testEmptyObject(b: *Build, opts: Options) *Step {
    const test_step = addTestStep(b, "empty-object", opts);

    const exe = addExecutable(b, "test", opts);
    addCSourceBytes(exe, "int main() { return 0; }", &.{});
    addCSourceBytes(exe, "", &.{});
    exe.linkLibC();

    const run = addRunArtifact(exe);
    run.expectExitCode(0);
    test_step.dependOn(&run.step);

    return test_step;
}

fn testEntryPoint(b: *Build, opts: Options) *Step {
    const test_step = addTestStep(b, "entry-point", opts);

    const a_o = addObject(b, "a", opts);
    addAsmSourceBytes(a_o,
        \\.globl foo, bar
        \\foo = 0x1000
        \\bar = 0x2000
    );

    const b_o = addObject(b, "b", opts);
    addCSourceBytes(b_o, "int main() { return 0; }", &.{});

    {
        const exe = addExecutable(b, "main", opts);
        exe.addObject(a_o);
        exe.addObject(b_o);
        exe.entry_symbol_name = "foo";

        const check = exe.checkObject();
        check.checkStart();
        check.checkExact("header");
        check.checkExact("entry 1000");
        test_step.dependOn(&check.step);
    }

    {
        // TODO looks like not assigning a unique name to this executable will
        // cause an artifact collision taking the cached executable from the above
        // step instead of generating a new one.
        const exe = addExecutable(b, "other", opts);
        exe.addObject(a_o);
        exe.addObject(b_o);
        exe.entry_symbol_name = "bar";

        const check = exe.checkObject();
        check.checkStart();
        check.checkExact("header");
        check.checkExact("entry 2000");
        test_step.dependOn(&check.step);
    }

    return test_step;
}

fn testExportDynamic(b: *Build, opts: Options) *Step {
    const test_step = addTestStep(b, "export-dynamic", opts);

    const obj = addObject(b, "obj", opts);
    addAsmSourceBytes(obj,
        \\.text
        \\  .globl foo
        \\  .hidden foo
        \\foo:
        \\  nop
        \\  .globl bar
        \\bar:
        \\  nop
        \\  .globl _start
        \\_start:
        \\  nop
    );

    const dso = addSharedLibrary(b, "a", opts);
    addCSourceBytes(dso, "int baz = 10;", &.{"-fPIC"});

    const exe = addExecutable(b, "main", opts);
    addCSourceBytes(exe,
        \\extern int baz;
        \\int callBaz() {
        \\  return baz;
        \\}
    , &.{});
    exe.addObject(obj);
    exe.linkLibrary(dso);
    exe.rdynamic = true;

    const check = exe.checkObject();
    check.checkInDynamicSymtab();
    check.checkContains("bar");
    check.checkInDynamicSymtab();
    check.checkContains("_start");
    test_step.dependOn(&check.step);

    return test_step;
}

fn testExportSymbolsFromExe(b: *Build, opts: Options) *Step {
    const test_step = addTestStep(b, "export-symbols-from-exe", opts);

    const dso = addSharedLibrary(b, "a", opts);
    addCSourceBytes(dso,
        \\void expfn1();
        \\void expfn2() {}
        \\
        \\void foo() {
        \\  expfn1();
        \\}
    , &.{"-fPIC"});

    const exe = addExecutable(b, "main", opts);
    addCSourceBytes(exe,
        \\void expfn1() {}
        \\void expfn2() {}
        \\void foo();
        \\
        \\int main() {
        \\  expfn1();
        \\  expfn2();
        \\  foo();
        \\}
    , &.{});
    exe.linkLibrary(dso);
    exe.linkLibC();

    const check = exe.checkObject();
    check.checkInDynamicSymtab();
    check.checkContains("expfn2");
    check.checkInDynamicSymtab();
    check.checkContains("expfn1");
    test_step.dependOn(&check.step);

    return test_step;
}

fn testGcSections(b: *Build, opts: Options) *Step {
    const test_step = addTestStep(b, "gc-sections", opts);

    const obj = addObject(b, "obj", opts);
    addCppSourceBytes(obj,
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
    , &.{});
    obj.link_function_sections = true;
    obj.link_data_sections = true;
    obj.linkLibC();
    obj.linkLibCpp();

    {
        const exe = addExecutable(b, "test", opts);
        exe.addObject(obj);
        exe.link_gc_sections = false;
        exe.linkLibC();
        exe.linkLibCpp();

        const run = addRunArtifact(exe);
        run.expectStdOutEqual("1 2\n");
        test_step.dependOn(&run.step);

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
    }

    {
        const exe = addExecutable(b, "test", opts);
        exe.addObject(obj);
        exe.link_gc_sections = true;
        exe.linkLibC();
        exe.linkLibCpp();

        const run = addRunArtifact(exe);
        run.expectStdOutEqual("1 2\n");
        test_step.dependOn(&run.step);

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
    }

    return test_step;
}

fn testLargeAlignmentDso(b: *Build, opts: Options) *Step {
    const test_step = addTestStep(b, "large-alignment-dso", opts);

    const dso = addSharedLibrary(b, "dso", opts);
    addCSourceBytes(dso,
        \\#include <stdio.h>
        \\#include <stdint.h>
        \\void hello() __attribute__((aligned(32768), section(".hello")));
        \\void world() __attribute__((aligned(32768), section(".world")));
        \\void hello() {
        \\  printf("Hello");
        \\}
        \\void world() {
        \\  printf(" world");
        \\}
        \\void greet() {
        \\  hello();
        \\  world();
        \\}
    , &.{"-fPIC"});
    dso.link_function_sections = true;
    dso.linkLibC();

    const check = dso.checkObject();
    check.checkInSymtab();
    check.checkExtract("{addr1} {size1} {shndx1} FUNC GLOBAL DEFAULT hello");
    check.checkInSymtab();
    check.checkExtract("{addr2} {size2} {shndx2} FUNC GLOBAL DEFAULT world");
    check.checkComputeCompare("addr1 16 %", .{ .op = .eq, .value = .{ .literal = 0 } });
    check.checkComputeCompare("addr2 16 %", .{ .op = .eq, .value = .{ .literal = 0 } });
    test_step.dependOn(&check.step);

    const exe = addExecutable(b, "test", opts);
    addCSourceBytes(exe,
        \\void greet();
        \\int main() { greet(); }
    , &.{});
    exe.linkLibrary(dso);
    exe.linkLibC();

    const run = addRunArtifact(exe);
    run.expectStdOutEqual("Hello world");
    test_step.dependOn(&run.step);

    return test_step;
}

fn testLargeAlignmentExe(b: *Build, opts: Options) *Step {
    const test_step = addTestStep(b, "large-alignment-exe", opts);

    const exe = addExecutable(b, "test", opts);
    addCSourceBytes(exe,
        \\#include <stdio.h>
        \\#include <stdint.h>
        \\
        \\void hello() __attribute__((aligned(32768), section(".hello")));
        \\void world() __attribute__((aligned(32768), section(".world")));
        \\
        \\void hello() {
        \\  printf("Hello");
        \\}
        \\
        \\void world() {
        \\  printf(" world");
        \\}
        \\
        \\int main() {
        \\  hello();
        \\  world();
        \\}
    , &.{});
    exe.link_function_sections = true;
    exe.linkLibC();

    const run = addRunArtifact(exe);
    run.expectStdOutEqual("Hello world");
    test_step.dependOn(&run.step);

    const check = exe.checkObject();
    check.checkInSymtab();
    check.checkExtract("{addr1} {size1} {shndx1} FUNC LOCAL DEFAULT hello");
    check.checkInSymtab();
    check.checkExtract("{addr2} {size2} {shndx2} FUNC LOCAL DEFAULT world");
    check.checkComputeCompare("addr1 16 %", .{ .op = .eq, .value = .{ .literal = 0 } });
    check.checkComputeCompare("addr2 16 %", .{ .op = .eq, .value = .{ .literal = 0 } });
    test_step.dependOn(&check.step);

    return test_step;
}

fn testLinkingC(b: *Build, opts: Options) *Step {
    const test_step = addTestStep(b, "linking-c", opts);

    const exe = addExecutable(b, "test", opts);
    addCSourceBytes(exe,
        \\#include <stdio.h>
        \\int main() {
        \\  printf("Hello World!\n");
        \\  return 0;
        \\}
    , &.{});
    exe.linkLibC();

    const run = addRunArtifact(exe);
    run.expectStdOutEqual("Hello World!\n");
    test_step.dependOn(&run.step);

    const check = exe.checkObject();
    check.checkStart();
    check.checkExact("header");
    check.checkExact("type EXEC");
    check.checkStart();
    check.checkExact("section headers");
    check.checkNotPresent("name .dynamic");
    test_step.dependOn(&check.step);

    return test_step;
}

fn testLinkingCpp(b: *Build, opts: Options) *Step {
    const test_step = addTestStep(b, "linking-cpp", opts);

    const exe = addExecutable(b, "test", opts);
    addCppSourceBytes(exe,
        \\#include <iostream>
        \\int main() {
        \\  std::cout << "Hello World!" << std::endl;
        \\  return 0;
        \\}
    , &.{});
    exe.linkLibC();
    exe.linkLibCpp();

    const run = addRunArtifact(exe);
    run.expectStdOutEqual("Hello World!\n");
    test_step.dependOn(&run.step);

    const check = exe.checkObject();
    check.checkStart();
    check.checkExact("header");
    check.checkExact("type EXEC");
    check.checkStart();
    check.checkExact("section headers");
    check.checkNotPresent("name .dynamic");
    test_step.dependOn(&check.step);

    return test_step;
}

fn testLinkingZig(b: *Build, opts: Options) *Step {
    const test_step = addTestStep(b, "linking-zig-static", opts);

    const exe = addExecutable(b, "test", opts);
    addZigSourceBytes(exe,
        \\pub fn main() void {
        \\    @import("std").debug.print("Hello World!\n", .{});
        \\}
    );

    const run = addRunArtifact(exe);
    run.expectStdErrEqual("Hello World!\n");
    test_step.dependOn(&run.step);

    const check = exe.checkObject();
    check.checkStart();
    check.checkExact("header");
    check.checkExact("type EXEC");
    check.checkStart();
    check.checkExact("section headers");
    check.checkNotPresent("name .dynamic");
    test_step.dependOn(&check.step);

    return test_step;
}

fn testTlsStatic(b: *Build, opts: Options) *Step {
    const test_step = addTestStep(b, "tls-static", opts);

    const exe = addExecutable(b, "test", opts);
    addCSourceBytes(exe,
        \\#include <stdio.h>
        \\_Thread_local int a = 10;
        \\_Thread_local int b;
        \\_Thread_local char c = 'a';
        \\int main(int argc, char* argv[]) {
        \\  printf("%d %d %c\n", a, b, c);
        \\  a += 1;
        \\  b += 1;
        \\  c += 1;
        \\  printf("%d %d %c\n", a, b, c);
        \\  return 0;
        \\}
    , &.{});
    exe.linkLibC();

    const run = addRunArtifact(exe);
    run.expectStdOutEqual(
        \\10 0 a
        \\11 1 b
        \\
    );
    test_step.dependOn(&run.step);

    return test_step;
}

const Options = struct {
    target: CrossTarget = .{ .cpu_arch = .x86_64, .os_tag = .linux },
    optimize: std.builtin.OptimizeMode = .Debug,
    use_llvm: bool = true,
    dynamic_linker: ?[]const u8 = null,
};

fn addTestStep(b: *Build, comptime prefix: []const u8, opts: Options) *Step {
    const target = opts.target.zigTriple(b.allocator) catch @panic("OOM");
    const optimize = @tagName(opts.optimize);
    const use_llvm = if (opts.use_llvm) "llvm" else "no-llvm";
    const name = std.fmt.allocPrint(b.allocator, "test-elf-" ++ prefix ++ "-{s}-{s}-{s}", .{
        target,
        optimize,
        use_llvm,
    }) catch @panic("OOM");
    return b.step(name, "");
}

fn addExecutable(b: *Build, name: []const u8, opts: Options) *Compile {
    const exe = b.addExecutable(.{
        .name = name,
        .target = opts.target,
        .optimize = opts.optimize,
        .use_llvm = opts.use_llvm,
        .use_lld = false,
    });
    exe.link_dynamic_linker = opts.dynamic_linker;
    return exe;
}

fn addObject(b: *Build, name: []const u8, opts: Options) *Compile {
    return b.addObject(.{
        .name = name,
        .target = opts.target,
        .optimize = opts.optimize,
        .use_llvm = opts.use_llvm,
        .use_lld = false,
    });
}

fn addStaticLibrary(b: *Build, name: []const u8, opts: Options) *Compile {
    return b.addStaticLibrary(.{
        .name = name,
        .target = opts.target,
        .optimize = opts.optimize,
        .use_llvm = opts.use_llvm,
        .use_lld = true,
    });
}

fn addSharedLibrary(b: *Build, name: []const u8, opts: Options) *Compile {
    const dso = b.addSharedLibrary(.{
        .name = name,
        .target = opts.target,
        .optimize = opts.optimize,
        .use_llvm = opts.use_llvm,
        .use_lld = false,
    });
    dso.link_dynamic_linker = opts.dynamic_linker;
    return dso;
}

fn addRunArtifact(comp: *Compile) *Run {
    const b = comp.step.owner;
    const run = b.addRunArtifact(comp);
    run.skip_foreign_checks = true;
    return run;
}

fn addZigSourceBytes(comp: *Compile, bytes: []const u8) void {
    const b = comp.step.owner;
    const file = WriteFile.create(b).add("a.zig", bytes);
    file.addStepDependencies(&comp.step);
    comp.root_src = file;
}

fn addCSourceBytes(comp: *Compile, bytes: []const u8, flags: []const []const u8) void {
    const b = comp.step.owner;
    const file = WriteFile.create(b).add("a.c", bytes);
    comp.addCSourceFile(.{ .file = file, .flags = flags });
}

fn addCppSourceBytes(comp: *Compile, bytes: []const u8, flags: []const []const u8) void {
    const b = comp.step.owner;
    const file = WriteFile.create(b).add("a.cpp", bytes);
    comp.addCSourceFile(.{ .file = file, .flags = flags });
}

fn addAsmSourceBytes(comp: *Compile, bytes: []const u8) void {
    const b = comp.step.owner;
    const actual_bytes = std.fmt.allocPrint(b.allocator, "{s}\n", .{bytes}) catch @panic("OOM");
    const file = WriteFile.create(b).add("a.s", actual_bytes);
    comp.addAssemblyFile(file);
}

const std = @import("std");

const Build = std.Build;
const Compile = Step.Compile;
const CrossTarget = std.zig.CrossTarget;
const LazyPath = Build.LazyPath;
const Run = Step.Run;
const Step = Build.Step;
const WriteFile = Step.WriteFile;

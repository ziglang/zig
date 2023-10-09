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

    // Exercise linker with self-hosted backend (no LLVM)
    // elf_step.dependOn(testLinkingZig(b, .{ .use_llvm = false }));

    // Exercise linker with LLVM backend
    // musl tests
    elf_step.dependOn(testAbsSymbols(b, .{ .target = musl_target }));
    elf_step.dependOn(testCommonSymbols(b, .{ .target = musl_target }));
    elf_step.dependOn(testCommonSymbolsInArchive(b, .{ .target = musl_target }));
    elf_step.dependOn(testEmptyObject(b, .{ .target = musl_target }));
    elf_step.dependOn(testEntryPoint(b, .{ .target = musl_target }));
    elf_step.dependOn(testGcSections(b, .{ .target = musl_target }));
    elf_step.dependOn(testImageBase(b, .{ .target = musl_target }));
    elf_step.dependOn(testInitArrayOrder(b, .{ .target = musl_target }));
    elf_step.dependOn(testLargeAlignmentExe(b, .{ .target = musl_target }));
    // https://github.com/ziglang/zig/issues/17449
    // elf_step.dependOn(testLargeBss(b, .{ .target = musl_target }));
    elf_step.dependOn(testLinkingC(b, .{ .target = musl_target }));
    elf_step.dependOn(testLinkingCpp(b, .{ .target = musl_target }));
    elf_step.dependOn(testLinkingZig(b, .{ .target = musl_target }));
    // https://github.com/ziglang/zig/issues/17451
    // elf_step.dependOn(testNoEhFrameHdr(b, .{ .target = musl_target }));
    elf_step.dependOn(testTlsStatic(b, .{ .target = musl_target }));

    // glibc tests
    elf_step.dependOn(testAsNeeded(b, .{ .target = glibc_target }));
    // https://github.com/ziglang/zig/issues/17430
    // elf_step.dependOn(testCanonicalPlt(b, .{ .target = glibc_target }));
    elf_step.dependOn(testCopyrel(b, .{ .target = glibc_target }));
    // https://github.com/ziglang/zig/issues/17430
    // elf_step.dependOn(testCopyrelAlias(b, .{ .target = glibc_target }));
    // https://github.com/ziglang/zig/issues/17430
    // elf_step.dependOn(testCopyrelAlignment(b, .{ .target = glibc_target }));
    elf_step.dependOn(testDsoPlt(b, .{ .target = glibc_target }));
    elf_step.dependOn(testDsoUndef(b, .{ .target = glibc_target }));
    elf_step.dependOn(testExportDynamic(b, .{ .target = glibc_target }));
    elf_step.dependOn(testExportSymbolsFromExe(b, .{ .target = glibc_target }));
    // https://github.com/ziglang/zig/issues/17430
    // elf_step.dependOn(testFuncAddress(b, .{ .target = glibc_target }));
    elf_step.dependOn(testHiddenWeakUndef(b, .{ .target = glibc_target }));
    elf_step.dependOn(testIFuncAlias(b, .{ .target = glibc_target }));
    // https://github.com/ziglang/zig/issues/17430
    // elf_step.dependOn(testIFuncDlopen(b, .{ .target = glibc_target }));
    elf_step.dependOn(testIFuncDso(b, .{ .target = glibc_target }));
    elf_step.dependOn(testIFuncDynamic(b, .{ .target = glibc_target }));
    elf_step.dependOn(testIFuncExport(b, .{ .target = glibc_target }));
    elf_step.dependOn(testIFuncFuncPtr(b, .{ .target = glibc_target }));
    elf_step.dependOn(testIFuncNoPlt(b, .{ .target = glibc_target }));
    // https://github.com/ziglang/zig/issues/17430 ??
    // elf_step.dependOn(testIFuncStatic(b, .{ .target = glibc_target }));
    // elf_step.dependOn(testIFuncStaticPie(b, .{ .target = glibc_target }));
    elf_step.dependOn(testInitArrayOrder(b, .{ .target = glibc_target }));
    elf_step.dependOn(testLargeAlignmentDso(b, .{ .target = glibc_target }));
    elf_step.dependOn(testLargeAlignmentExe(b, .{ .target = glibc_target }));
    elf_step.dependOn(testLargeBss(b, .{ .target = glibc_target }));
    elf_step.dependOn(testLinkOrder(b, .{ .target = glibc_target }));
    // https://github.com/ziglang/zig/issues/17451
    // elf_step.dependOn(testNoEhFrameHdr(b, .{ .target = glibc_target }));
    elf_step.dependOn(testPie(b, .{ .target = glibc_target }));
    elf_step.dependOn(testPltGot(b, .{ .target = glibc_target }));
    elf_step.dependOn(testPreinitArray(b, .{ .target = glibc_target }));
    elf_step.dependOn(testSharedAbsSymbol(b, .{ .target = glibc_target }));
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
    addCSourceBytes(libfoo, "int foo() { return 42; }", &.{});

    const libbar = addSharedLibrary(b, "bar", opts);
    addCSourceBytes(libbar, "int bar() { return 42; }", &.{});

    const libbaz = addSharedLibrary(b, "baz", opts);
    addCSourceBytes(libbaz,
        \\int foo();
        \\int baz() { return foo(); }
    , &.{});

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
    , &.{});

    const b_o = addObject(b, "obj", opts);
    addCSourceBytes(b_o,
        \\void *bar();
        \\void *baz() {
        \\  return bar;
        \\}
    , &.{});
    b_o.force_pic = true;

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
    , &.{});
    main_o.linkLibC();
    main_o.force_pic = false;

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
    , &.{});

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
    , &.{});

    const exe = addExecutable(b, "main", opts);
    addCSourceBytes(exe,
        \\#include<stdio.h>
        \\extern int foo;
        \\extern int *get_bar();
        \\int main() {
        \\  printf("%d %d %d\n", foo, *get_bar(), &foo == get_bar());
        \\  return 0;
        \\}
    , &.{});
    addCSourceBytes(exe,
        \\extern int bar;
        \\int *get_bar() { return &bar; }
    , &.{});
    exe.linkLibrary(dso);
    exe.linkLibC();
    exe.force_pic = false;
    exe.pie = false;

    const run = addRunArtifact(exe);
    run.expectStdOutEqual("42 42 1\n");
    test_step.dependOn(&run.step);

    return test_step;
}

fn testCopyrelAlignment(b: *Build, opts: Options) *Step {
    const test_step = addTestStep(b, "copyrel-alignment", opts);

    const a_so = addSharedLibrary(b, "a", opts);
    addCSourceBytes(a_so, "__attribute__((aligned(32))) int foo = 5;", &.{});

    const b_so = addSharedLibrary(b, "b", opts);
    addCSourceBytes(b_so, "__attribute__((aligned(8))) int foo = 5;", &.{});

    const c_so = addSharedLibrary(b, "c", opts);
    addCSourceBytes(c_so, "__attribute__((aligned(256))) int foo = 5;", &.{});

    const obj = addObject(b, "main", opts);
    addCSourceBytes(obj,
        \\#include <stdio.h>
        \\extern int foo;
        \\int main() { printf("%d\n", foo); }
    , &.{});
    obj.linkLibC();
    obj.force_pic = false;

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
    , &.{});
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
    , &.{});
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
    addCSourceBytes(dso, "int baz = 10;", &.{});

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
    , &.{});

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

fn testFuncAddress(b: *Build, opts: Options) *Step {
    const test_step = addTestStep(b, "func-address", opts);

    const dso = addSharedLibrary(b, "a", opts);
    addCSourceBytes(dso, "void fn() {}", &.{});

    const exe = addExecutable(b, "main", opts);
    addCSourceBytes(exe,
        \\#include <assert.h>
        \\typedef void Func();
        \\void fn();
        \\Func *const ptr = fn;
        \\int main() {
        \\  assert(fn == ptr);
        \\}
    , &.{});
    exe.linkLibrary(dso);
    exe.force_pic = false;
    exe.pie = false;

    const run = addRunArtifact(exe);
    test_step.dependOn(&run.step);

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

fn testHiddenWeakUndef(b: *Build, opts: Options) *Step {
    const test_step = addTestStep(b, "hidden-weak-undef", opts);

    const dso = addSharedLibrary(b, "a", opts);
    addCSourceBytes(dso,
        \\__attribute__((weak, visibility("hidden"))) void foo();
        \\void bar() { foo(); }
    , &.{});

    const check = dso.checkObject();
    check.checkInDynamicSymtab();
    check.checkNotPresent("foo");
    check.checkInDynamicSymtab();
    check.checkContains("bar");
    test_step.dependOn(&check.step);

    return test_step;
}

fn testIFuncAlias(b: *Build, opts: Options) *Step {
    const test_step = addTestStep(b, "ifunc-alias", opts);

    const exe = addExecutable(b, "main", opts);
    addCSourceBytes(exe,
        \\#include <assert.h>
        \\void foo() {}
        \\int bar() __attribute__((ifunc("resolve_bar")));
        \\void *resolve_bar() { return foo; }
        \\void *bar2 = bar;
        \\int main() {
        \\  assert(bar == bar2);
        \\}
    , &.{});
    exe.force_pic = true;
    exe.linkLibC();

    const run = addRunArtifact(exe);
    run.expectExitCode(0);
    test_step.dependOn(&run.step);

    return test_step;
}

fn testIFuncDlopen(b: *Build, opts: Options) *Step {
    const test_step = addTestStep(b, "ifunc-dlopen", opts);

    const dso = addSharedLibrary(b, "a", opts);
    addCSourceBytes(dso,
        \\__attribute__((ifunc("resolve_foo")))
        \\void foo(void);
        \\static void real_foo(void) {
        \\}
        \\typedef void Func();
        \\static Func *resolve_foo(void) {
        \\  return real_foo;
        \\}
    , &.{});

    const exe = addExecutable(b, "main", opts);
    addCSourceBytes(exe,
        \\#include <dlfcn.h>
        \\#include <assert.h>
        \\#include <stdlib.h>
        \\typedef void Func();
        \\void foo(void);
        \\int main() {
        \\  void *handle = dlopen(NULL, RTLD_NOW);
        \\  Func *p = dlsym(handle, "foo");
        \\
        \\  foo();
        \\  p();
        \\  assert(foo == p);
        \\}
    , &.{});
    exe.linkLibrary(dso);
    exe.linkLibC();
    exe.linkSystemLibrary2("dl", .{});
    exe.force_pic = false;
    exe.pie = false;

    const run = addRunArtifact(exe);
    test_step.dependOn(&run.step);

    return test_step;
}

fn testIFuncDso(b: *Build, opts: Options) *Step {
    const test_step = addTestStep(b, "ifunc-dso", opts);

    const dso = addSharedLibrary(b, "a", opts);
    addCSourceBytes(dso,
        \\#include<stdio.h>
        \\__attribute__((ifunc("resolve_foobar")))
        \\void foobar(void);
        \\static void real_foobar(void) {
        \\  printf("Hello world\n");
        \\}
        \\typedef void Func();
        \\static Func *resolve_foobar(void) {
        \\  return real_foobar;
        \\}
    , &.{});
    dso.linkLibC();

    const exe = addExecutable(b, "main", opts);
    addCSourceBytes(exe,
        \\void foobar(void);
        \\int main() {
        \\  foobar();
        \\}
    , &.{});
    exe.linkLibrary(dso);

    const run = addRunArtifact(exe);
    run.expectStdOutEqual("Hello world\n");
    test_step.dependOn(&run.step);

    return test_step;
}

fn testIFuncDynamic(b: *Build, opts: Options) *Step {
    const test_step = addTestStep(b, "ifunc-dynamic", opts);

    const main_c =
        \\#include <stdio.h>
        \\__attribute__((ifunc("resolve_foobar")))
        \\static void foobar(void);
        \\static void real_foobar(void) {
        \\  printf("Hello world\n");
        \\}
        \\typedef void Func();
        \\static Func *resolve_foobar(void) {
        \\  return real_foobar;
        \\}
        \\int main() {
        \\  foobar();
        \\}
    ;

    {
        const exe = addExecutable(b, "main", opts);
        addCSourceBytes(exe, main_c, &.{});
        exe.linkLibC();
        exe.link_z_lazy = true;

        const run = addRunArtifact(exe);
        run.expectStdOutEqual("Hello world\n");
        test_step.dependOn(&run.step);
    }
    {
        const exe = addExecutable(b, "other", opts);
        addCSourceBytes(exe, main_c, &.{});
        exe.linkLibC();

        const run = addRunArtifact(exe);
        run.expectStdOutEqual("Hello world\n");
        test_step.dependOn(&run.step);
    }

    return test_step;
}

fn testIFuncExport(b: *Build, opts: Options) *Step {
    const test_step = addTestStep(b, "ifunc-export", opts);

    const dso = addSharedLibrary(b, "a", opts);
    addCSourceBytes(dso,
        \\#include <stdio.h>
        \\__attribute__((ifunc("resolve_foobar")))
        \\void foobar(void);
        \\void real_foobar(void) {
        \\  printf("Hello world\n");
        \\}
        \\typedef void Func();
        \\Func *resolve_foobar(void) {
        \\  return real_foobar;
        \\}
    , &.{});
    dso.linkLibC();

    const check = dso.checkObject();
    check.checkInDynamicSymtab();
    check.checkContains("IFUNC GLOBAL DEFAULT foobar");
    test_step.dependOn(&check.step);

    return test_step;
}

fn testIFuncFuncPtr(b: *Build, opts: Options) *Step {
    const test_step = addTestStep(b, "ifunc-func-ptr", opts);

    const exe = addExecutable(b, "main", opts);
    addCSourceBytes(exe,
        \\typedef int Fn();
        \\int foo() __attribute__((ifunc("resolve_foo")));
        \\int real_foo() { return 3; }
        \\Fn *resolve_foo(void) {
        \\  return real_foo;
        \\}
    , &.{});
    addCSourceBytes(exe,
        \\typedef int Fn();
        \\int foo();
        \\Fn *get_foo() { return foo; }
    , &.{});
    addCSourceBytes(exe,
        \\#include <stdio.h>
        \\typedef int Fn();
        \\Fn *get_foo();
        \\int main() {
        \\  Fn *f = get_foo();
        \\  printf("%d\n", f());
        \\}
    , &.{});
    exe.force_pic = true;
    exe.linkLibC();

    const run = addRunArtifact(exe);
    run.expectStdOutEqual("3\n");
    test_step.dependOn(&run.step);

    return test_step;
}

fn testIFuncNoPlt(b: *Build, opts: Options) *Step {
    const test_step = addTestStep(b, "ifunc-noplt", opts);

    const exe = addExecutable(b, "main", opts);
    addCSourceBytes(exe,
        \\#include <stdio.h>
        \\__attribute__((ifunc("resolve_foo")))
        \\void foo(void);
        \\void hello(void) {
        \\  printf("Hello world\n");
        \\}
        \\typedef void Fn();
        \\Fn *resolve_foo(void) {
        \\  return hello;
        \\}
        \\int main() {
        \\  foo();
        \\}
    , &.{"-fno-plt"});
    exe.force_pic = true;
    exe.linkLibC();

    const run = addRunArtifact(exe);
    run.expectStdOutEqual("Hello world\n");
    test_step.dependOn(&run.step);

    return test_step;
}

fn testIFuncStatic(b: *Build, opts: Options) *Step {
    const test_step = addTestStep(b, "ifunc-static", opts);

    const exe = addExecutable(b, "main", opts);
    addCSourceBytes(exe,
        \\#include <stdio.h>
        \\void foo() __attribute__((ifunc("resolve_foo")));
        \\void hello() {
        \\  printf("Hello world\n");
        \\}
        \\void *resolve_foo() {
        \\  return hello;
        \\}
        \\int main() {
        \\  foo();
        \\  return 0;
        \\}
    , &.{});
    exe.linkLibC();
    exe.linkage = .static;

    const run = addRunArtifact(exe);
    run.expectStdOutEqual("Hello world\n");
    test_step.dependOn(&run.step);

    return test_step;
}

fn testIFuncStaticPie(b: *Build, opts: Options) *Step {
    const test_step = addTestStep(b, "ifunc-static-pie", opts);

    const exe = addExecutable(b, "main", opts);
    addCSourceBytes(exe,
        \\#include <stdio.h>
        \\void foo() __attribute__((ifunc("resolve_foo")));
        \\void hello() {
        \\  printf("Hello world\n");
        \\}
        \\void *resolve_foo() {
        \\  return hello;
        \\}
        \\int main() {
        \\  foo();
        \\  return 0;
        \\}
    , &.{});
    exe.linkage = .static;
    exe.force_pic = true;
    exe.pie = true;
    exe.linkLibC();

    const run = addRunArtifact(exe);
    run.expectStdOutEqual("Hello world\n");
    test_step.dependOn(&run.step);

    const check = exe.checkObject();
    check.checkStart();
    check.checkExact("header");
    check.checkExact("type DYN");
    check.checkStart();
    check.checkExact("section headers");
    check.checkExact("name .dynamic");
    check.checkStart();
    check.checkExact("section headers");
    check.checkNotPresent("name .interp");
    test_step.dependOn(&check.step);

    return test_step;
}

fn testImageBase(b: *Build, opts: Options) *Step {
    const test_step = addTestStep(b, "image-base", opts);

    {
        const exe = addExecutable(b, "main1", opts);
        addCSourceBytes(exe,
            \\#include <stdio.h>
            \\int main() {
            \\  printf("Hello World!\n");
            \\  return 0;
            \\}
        , &.{});
        exe.linkLibC();
        exe.image_base = 0x8000000;

        const run = addRunArtifact(exe);
        run.expectStdOutEqual("Hello World!\n");
        test_step.dependOn(&run.step);

        const check = exe.checkObject();
        check.checkStart();
        check.checkExact("header");
        check.checkExtract("entry {addr}");
        check.checkComputeCompare("addr", .{ .op = .gte, .value = .{ .literal = 0x8000000 } });
        test_step.dependOn(&check.step);
    }

    {
        const exe = addExecutable(b, "main2", opts);
        addCSourceBytes(exe, "void _start() {}", &.{});
        exe.image_base = 0xffffffff8000000;

        const check = exe.checkObject();
        check.checkStart();
        check.checkExact("header");
        check.checkExtract("entry {addr}");
        check.checkComputeCompare("addr", .{ .op = .gte, .value = .{ .literal = 0xffffffff8000000 } });
        test_step.dependOn(&check.step);
    }

    return test_step;
}

fn testInitArrayOrder(b: *Build, opts: Options) *Step {
    const test_step = addTestStep(b, "init-array-order", opts);

    const a_o = addObject(b, "a", opts);
    addCSourceBytes(a_o,
        \\#include <stdio.h>
        \\__attribute__((constructor(10000))) void init4() { printf("1"); }
    , &.{});
    a_o.linkLibC();

    const b_o = addObject(b, "b", opts);
    addCSourceBytes(b_o,
        \\#include <stdio.h>
        \\__attribute__((constructor(1000))) void init3() { printf("2"); }
    , &.{});
    b_o.linkLibC();

    const c_o = addObject(b, "c", opts);
    addCSourceBytes(c_o,
        \\#include <stdio.h>
        \\__attribute__((constructor)) void init1() { printf("3"); }
    , &.{});
    c_o.linkLibC();

    const d_o = addObject(b, "d", opts);
    addCSourceBytes(d_o,
        \\#include <stdio.h>
        \\__attribute__((constructor)) void init2() { printf("4"); }
    , &.{});
    d_o.linkLibC();

    const e_o = addObject(b, "e", opts);
    addCSourceBytes(e_o,
        \\#include <stdio.h>
        \\__attribute__((destructor(10000))) void fini4() { printf("5"); }
    , &.{});
    e_o.linkLibC();

    const f_o = addObject(b, "f", opts);
    addCSourceBytes(f_o,
        \\#include <stdio.h>
        \\__attribute__((destructor(1000))) void fini3() { printf("6"); }
    , &.{});
    f_o.linkLibC();

    const g_o = addObject(b, "g", opts);
    addCSourceBytes(g_o,
        \\#include <stdio.h>
        \\__attribute__((destructor)) void fini1() { printf("7"); }
    , &.{});
    g_o.linkLibC();

    const h_o = addObject(b, "h", opts);
    addCSourceBytes(h_o,
        \\#include <stdio.h>
        \\__attribute__((destructor)) void fini2() { printf("8"); }
    , &.{});
    h_o.linkLibC();

    const exe = addExecutable(b, "main", opts);
    addCSourceBytes(exe, "int main() { return 0; }", &.{});
    exe.addObject(a_o);
    exe.addObject(b_o);
    exe.addObject(c_o);
    exe.addObject(d_o);
    exe.addObject(e_o);
    exe.addObject(f_o);
    exe.addObject(g_o);
    exe.addObject(h_o);

    const run = addRunArtifact(exe);
    run.expectStdOutEqual("21348756");
    test_step.dependOn(&run.step);

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
    , &.{});
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

fn testLargeBss(b: *Build, opts: Options) *Step {
    const test_step = addTestStep(b, "large-bss", opts);

    const exe = addExecutable(b, "main", opts);
    addCSourceBytes(exe,
        \\char arr[0x100000000];
        \\int main() {
        \\  return arr[2000];
        \\}
    , &.{});
    exe.linkLibC();

    const run = addRunArtifact(exe);
    test_step.dependOn(&run.step);

    return test_step;
}

fn testLinkOrder(b: *Build, opts: Options) *Step {
    const test_step = addTestStep(b, "link-order", opts);

    const obj = addObject(b, "obj", opts);
    addCSourceBytes(obj, "void foo() {}", &.{});
    obj.force_pic = true;

    const dso = addSharedLibrary(b, "a", opts);
    dso.addObject(obj);

    const lib = addStaticLibrary(b, "b", opts);
    lib.addObject(obj);

    const main_o = addObject(b, "main", opts);
    addCSourceBytes(main_o,
        \\void foo();
        \\int main() {
        \\  foo();
        \\}
    , &.{});

    // https://github.com/ziglang/zig/issues/17450
    // {
    //     const exe = addExecutable(b, "main1", opts);
    //     exe.addObject(main_o);
    //     exe.linkSystemLibrary2("a", .{});
    //     exe.addLibraryPath(dso.getEmittedBinDirectory());
    //     exe.addRPath(dso.getEmittedBinDirectory());
    //     exe.linkSystemLibrary2("b", .{});
    //     exe.addLibraryPath(lib.getEmittedBinDirectory());
    //     exe.addRPath(lib.getEmittedBinDirectory());
    //     exe.linkLibC();
    //     exe.verbose_link = true;

    //     const check = exe.checkObject();
    //     check.checkInDynamicSection();
    //     check.checkContains("libb.so");
    //     test_step.dependOn(&check.step);
    // }

    {
        const exe = addExecutable(b, "main2", opts);
        exe.addObject(main_o);
        exe.linkSystemLibrary2("b", .{});
        exe.addLibraryPath(lib.getEmittedBinDirectory());
        exe.addRPath(lib.getEmittedBinDirectory());
        exe.linkSystemLibrary2("a", .{});
        exe.addLibraryPath(dso.getEmittedBinDirectory());
        exe.addRPath(dso.getEmittedBinDirectory());
        exe.linkLibC();
        exe.verbose_link = true;

        const check = exe.checkObject();
        check.checkInDynamicSection();
        check.checkNotPresent("libb.so");
        test_step.dependOn(&check.step);
    }

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

fn testNoEhFrameHdr(b: *Build, opts: Options) *Step {
    const test_step = addTestStep(b, "no-eh-frame-hdr", opts);

    const exe = addExecutable(b, "main", opts);
    addCSourceBytes(exe, "int main() { return 0; }", &.{});
    exe.link_eh_frame_hdr = false;
    exe.linkLibC();

    const check = exe.checkObject();
    check.checkStart();
    check.checkExact("section headers");
    check.checkNotPresent("name .eh_frame_hdr");
    test_step.dependOn(&check.step);

    return test_step;
}

fn testPie(b: *Build, opts: Options) *Step {
    const test_step = addTestStep(b, "hello-pie", opts);

    const exe = addExecutable(b, "main", opts);
    addCSourceBytes(exe,
        \\#include <stdio.h>
        \\int main() {
        \\  printf("Hello!\n");
        \\  return 0;
        \\}
    , &.{});
    exe.linkLibC();
    exe.force_pic = true;
    exe.pie = true;

    const run = addRunArtifact(exe);
    run.expectStdOutEqual("Hello!\n");
    test_step.dependOn(&run.step);

    const check = exe.checkObject();
    check.checkStart();
    check.checkExact("header");
    check.checkExact("type DYN");
    check.checkStart();
    check.checkExact("section headers");
    check.checkExact("name .dynamic");
    test_step.dependOn(&check.step);

    return test_step;
}

fn testPltGot(b: *Build, opts: Options) *Step {
    const test_step = addTestStep(b, "plt-got", opts);

    const dso = addSharedLibrary(b, "a", opts);
    addCSourceBytes(dso,
        \\#include <stdio.h>
        \\void ignore(void *foo) {}
        \\void hello() {
        \\  printf("Hello world\n");
        \\}
    , &.{});
    dso.linkLibC();

    const exe = addExecutable(b, "main", opts);
    addCSourceBytes(exe,
        \\void ignore(void *);
        \\int hello();
        \\void foo() { ignore(hello); }
        \\int main() { hello(); }
    , &.{});
    exe.linkLibrary(dso);
    exe.force_pic = true;
    exe.linkLibC();

    const run = addRunArtifact(exe);
    run.expectStdOutEqual("Hello world\n");
    test_step.dependOn(&run.step);

    return test_step;
}

fn testPreinitArray(b: *Build, opts: Options) *Step {
    const test_step = addTestStep(b, "preinit-array", opts);

    {
        const obj = addObject(b, "obj", opts);
        addCSourceBytes(obj, "void _start() {}", &.{});

        const exe = addExecutable(b, "main1", opts);
        exe.addObject(obj);

        const check = exe.checkObject();
        check.checkInDynamicSection();
        check.checkNotPresent("PREINIT_ARRAY");
    }

    {
        const exe = addExecutable(b, "main2", opts);
        addCSourceBytes(exe,
            \\void preinit_fn() {}
            \\int main() {}
            \\__attribute__((section(".preinit_array")))
            \\void *preinit[] = { preinit_fn };
        , &.{});
        exe.linkLibC();

        const check = exe.checkObject();
        check.checkInDynamicSection();
        check.checkContains("PREINIT_ARRAY");
    }

    return test_step;
}

fn testSharedAbsSymbol(b: *Build, opts: Options) *Step {
    const test_step = addTestStep(b, "shared-abs-symbol", opts);

    const dso = addSharedLibrary(b, "a", opts);
    addAsmSourceBytes(dso,
        \\.globl foo
        \\foo = 3;
    );

    const obj = addObject(b, "obj", opts);
    addCSourceBytes(obj,
        \\#include <stdio.h>
        \\extern char foo;
        \\int main() { printf("foo=%p\n", &foo); }
    , &.{});
    obj.force_pic = true;
    obj.linkLibC();

    {
        const exe = addExecutable(b, "main1", opts);
        exe.addObject(obj);
        exe.linkLibrary(dso);
        exe.pie = true;

        const run = addRunArtifact(exe);
        run.expectStdOutEqual("foo=0x3\n");
        test_step.dependOn(&run.step);

        const check = exe.checkObject();
        check.checkStart();
        check.checkExact("header");
        check.checkExact("type DYN");
        // TODO fix/improve in CheckObject
        // check.checkInSymtab();
        // check.checkNotPresent("foo");
        test_step.dependOn(&check.step);
    }

    // https://github.com/ziglang/zig/issues/17430
    // {
    //     const exe = addExecutable(b, "main2", opts);
    //     exe.addObject(obj);
    //     exe.linkLibrary(dso);
    //     exe.pie = false;

    //     const run = addRunArtifact(exe);
    //     run.expectStdOutEqual("foo=0x3\n");
    //     test_step.dependOn(&run.step);

    //     const check = exe.checkObject();
    //     check.checkStart();
    //     check.checkExact("header");
    //     check.checkExact("type EXEC");
    //     // TODO fix/improve in CheckObject
    //     // check.checkInSymtab();
    //     // check.checkNotPresent("foo");
    //     test_step.dependOn(&check.step);
    // }

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
    return b.addExecutable(.{
        .name = name,
        .target = opts.target,
        .optimize = opts.optimize,
        .use_llvm = opts.use_llvm,
        .use_lld = false,
    });
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
    return b.addSharedLibrary(.{
        .name = name,
        .target = opts.target,
        .optimize = opts.optimize,
        .use_llvm = opts.use_llvm,
        .use_lld = false,
    });
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

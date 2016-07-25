/*
 * Copyright (c) 2015 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

#include "list.hpp"
#include "buffer.hpp"
#include "os.hpp"
#include "error.hpp"

#include <stdio.h>
#include <stdarg.h>

struct TestSourceFile {
    const char *relative_path;
    const char *source_code;
};

struct TestCase {
    const char *case_name;
    const char *output;
    ZigList<TestSourceFile> source_files;
    ZigList<const char *> compile_errors;
    ZigList<const char *> compiler_args;
    ZigList<const char *> program_args;
    bool is_parseh;
    bool is_self_hosted;
    bool is_release_mode;
    bool is_debug_safety;
};

static ZigList<TestCase*> test_cases = {0};
static const char *tmp_source_path = ".tmp_source.zig";
static const char *tmp_h_path = ".tmp_header.h";

#if defined(_WIN32)
static const char *tmp_exe_path = "./.tmp_exe.exe";
static const char *zig_exe = "./zig.exe";
#define NL "\r\n"
#else
static const char *tmp_exe_path = "./.tmp_exe";
static const char *zig_exe = "./zig";
#define NL "\n"
#endif

static void add_source_file(TestCase *test_case, const char *path, const char *source) {
    test_case->source_files.add_one();
    test_case->source_files.last().relative_path = path;
    test_case->source_files.last().source_code = source;
}

static TestCase *add_simple_case(const char *case_name, const char *source, const char *output) {
    TestCase *test_case = allocate<TestCase>(1);
    test_case->case_name = case_name;
    test_case->output = output;

    test_case->source_files.resize(1);
    test_case->source_files.at(0).relative_path = tmp_source_path;
    test_case->source_files.at(0).source_code = source;

    test_case->compiler_args.append("build");
    test_case->compiler_args.append(tmp_source_path);
    test_case->compiler_args.append("--export");
    test_case->compiler_args.append("exe");
    test_case->compiler_args.append("--name");
    test_case->compiler_args.append("test");
    test_case->compiler_args.append("--output");
    test_case->compiler_args.append(tmp_exe_path);
    test_case->compiler_args.append("--release");
    test_case->compiler_args.append("--strip");
    test_case->compiler_args.append("--color");
    test_case->compiler_args.append("on");
    test_case->compiler_args.append("--check-unused");

    test_cases.append(test_case);

    return test_case;
}

static TestCase *add_simple_case_libc(const char *case_name, const char *source, const char *output) {
    TestCase *tc = add_simple_case(case_name, source, output);
    tc->compiler_args.append("--library");
    tc->compiler_args.append("c");
    return tc;
}

static TestCase *add_compile_fail_case(const char *case_name, const char *source, int count, ...) {
    va_list ap;
    va_start(ap, count);

    TestCase *test_case = allocate<TestCase>(1);
    test_case->case_name = case_name;
    test_case->source_files.resize(1);
    test_case->source_files.at(0).relative_path = tmp_source_path;
    test_case->source_files.at(0).source_code = source;

    for (int i = 0; i < count; i += 1) {
        const char *arg = va_arg(ap, const char *);
        test_case->compile_errors.append(arg);
    }

    test_case->compiler_args.append("build");
    test_case->compiler_args.append(tmp_source_path);

    test_case->compiler_args.append("--name");
    test_case->compiler_args.append("test");

    test_case->compiler_args.append("--export");
    test_case->compiler_args.append("obj");

    test_case->compiler_args.append("--output");
    test_case->compiler_args.append(tmp_exe_path);

    test_case->compiler_args.append("--release");
    test_case->compiler_args.append("--strip");
    test_case->compiler_args.append("--check-unused");

    test_cases.append(test_case);

    va_end(ap);

    return test_case;
}

static void add_debug_safety_case(const char *case_name, const char *source) {
    {
        TestCase *test_case = allocate<TestCase>(1);
        test_case->is_debug_safety = true;
        test_case->case_name = buf_ptr(buf_sprintf("%s (debug)", case_name));
        test_case->source_files.resize(1);
        test_case->source_files.at(0).relative_path = tmp_source_path;
        test_case->source_files.at(0).source_code = source;

        test_case->compiler_args.append("build");
        test_case->compiler_args.append(tmp_source_path);

        test_case->compiler_args.append("--name");
        test_case->compiler_args.append("test");

        test_case->compiler_args.append("--export");
        test_case->compiler_args.append("exe");

        test_case->compiler_args.append("--output");
        test_case->compiler_args.append(tmp_exe_path);

        test_cases.append(test_case);
    }
    {
        TestCase *test_case = allocate<TestCase>(1);
        test_case->case_name = buf_ptr(buf_sprintf("%s (release)", case_name));
        test_case->source_files.resize(1);
        test_case->source_files.at(0).relative_path = tmp_source_path;
        test_case->source_files.at(0).source_code = source;
        test_case->output = "";

        test_case->compiler_args.append("build");
        test_case->compiler_args.append(tmp_source_path);

        test_case->compiler_args.append("--name");
        test_case->compiler_args.append("test");

        test_case->compiler_args.append("--export");
        test_case->compiler_args.append("exe");

        test_case->compiler_args.append("--output");
        test_case->compiler_args.append(tmp_exe_path);

        test_case->compiler_args.append("--release");

        test_cases.append(test_case);
    }
}

static TestCase *add_parseh_case(const char *case_name, const char *source, int count, ...) {
    va_list ap;
    va_start(ap, count);

    TestCase *test_case = allocate<TestCase>(1);
    test_case->case_name = case_name;
    test_case->is_parseh = true;

    test_case->source_files.resize(1);
    test_case->source_files.at(0).relative_path = tmp_h_path;
    test_case->source_files.at(0).source_code = source;

    for (int i = 0; i < count; i += 1) {
        const char *arg = va_arg(ap, const char *);
        test_case->compile_errors.append(arg);
    }

    test_case->compiler_args.append("parseh");
    test_case->compiler_args.append(tmp_h_path);
    test_case->compiler_args.append("--verbose");

    test_cases.append(test_case);

    va_end(ap);
    return test_case;
}

static void add_compiling_test_cases(void) {
    add_simple_case_libc("hello world with libc", R"SOURCE(
const c = @c_import(@c_include("stdio.h"));
export fn main(argc: c_int, argv: &&u8) -> c_int {
    c.puts(c"Hello, world!");
    return 0;
}
    )SOURCE", "Hello, world!" NL);

    {
        TestCase *tc = add_simple_case("multiple files with private function", R"SOURCE(
use @import("std").io;
use @import("foo.zig");

pub fn main(args: [][]u8) -> %void {
    private_function();
    %%stdout.printf("OK 2\n");
}

fn private_function() {
    print_text();
}
        )SOURCE", "OK 1\nOK 2\n");

        add_source_file(tc, "foo.zig", R"SOURCE(
use @import("std").io;

// purposefully conflicting function with main.zig
// but it's private so it should be OK
fn private_function() {
    %%stdout.printf("OK 1\n");
}

pub fn print_text() {
    private_function();
}
        )SOURCE");
    }

    {
        TestCase *tc = add_simple_case("import segregation", R"SOURCE(
use @import("foo.zig");
use @import("bar.zig");

pub fn main(args: [][]u8) -> %void {
    foo_function();
    bar_function();
}
        )SOURCE", "OK\nOK\n");

        add_source_file(tc, "foo.zig", R"SOURCE(
use @import("std").io;
pub fn foo_function() {
    %%stdout.printf("OK\n");
}
        )SOURCE");

        add_source_file(tc, "bar.zig", R"SOURCE(
use @import("other.zig");
use @import("std").io;

pub fn bar_function() {
    if (foo_function()) {
        %%stdout.printf("OK\n");
    }
}
        )SOURCE");

        add_source_file(tc, "other.zig", R"SOURCE(
#static_eval_enable(false)
pub fn foo_function() -> bool {
    // this one conflicts with the one from foo
    return true;
}
        )SOURCE");
    }

    {
        TestCase *tc = add_simple_case("two files use import each other", R"SOURCE(
use @import("a.zig");

pub fn main(args: [][]u8) -> %void {
    ok();
}
        )SOURCE", "OK\n");

        add_source_file(tc, "a.zig", R"SOURCE(
use @import("b.zig");
const io = @import("std").io;

pub const a_text = "OK\n";

pub fn ok() {
    %%io.stdout.printf(b_text);
}
        )SOURCE");

        add_source_file(tc, "b.zig", R"SOURCE(
use @import("a.zig");

pub const b_text = a_text;
        )SOURCE");
    }



    add_simple_case("hello world without libc", R"SOURCE(
const io = @import("std").io;

pub fn main(args: [][]u8) -> %void {
    %%io.stdout.printf("Hello, world!\n");
}
    )SOURCE", "Hello, world!\n");


    add_simple_case_libc("number literals", R"SOURCE(
const c = @c_import(@c_include("stdio.h"));

export fn main(argc: c_int, argv: &&u8) -> c_int {
    c.printf(c"\n");

    c.printf(c"0: %llu\n",
             u64(0));
    c.printf(c"320402575052271: %llu\n",
         u64(320402575052271));
    c.printf(c"0x01236789abcdef: %llu\n",
         u64(0x01236789abcdef));
    c.printf(c"0xffffffffffffffff: %llu\n",
         u64(0xffffffffffffffff));
    c.printf(c"0x000000ffffffffffffffff: %llu\n",
         u64(0x000000ffffffffffffffff));
    c.printf(c"0o1777777777777777777777: %llu\n",
         u64(0o1777777777777777777777));
    c.printf(c"0o0000001777777777777777777777: %llu\n",
         u64(0o0000001777777777777777777777));
    c.printf(c"0b1111111111111111111111111111111111111111111111111111111111111111: %llu\n",
         u64(0b1111111111111111111111111111111111111111111111111111111111111111));
    c.printf(c"0b0000001111111111111111111111111111111111111111111111111111111111111111: %llu\n",
         u64(0b0000001111111111111111111111111111111111111111111111111111111111111111));

    c.printf(c"\n");

    c.printf(c"0.0: %a\n",
         f64(0.0));
    c.printf(c"0e0: %a\n",
         f64(0e0));
    c.printf(c"0.0e0: %a\n",
         f64(0.0e0));
    c.printf(c"000000000000000000000000000000000000000000000000000000000.0e0: %a\n",
         f64(000000000000000000000000000000000000000000000000000000000.0e0));
    c.printf(c"0.000000000000000000000000000000000000000000000000000000000e0: %a\n",
         f64(0.000000000000000000000000000000000000000000000000000000000e0));
    c.printf(c"0.0e000000000000000000000000000000000000000000000000000000000: %a\n",
         f64(0.0e000000000000000000000000000000000000000000000000000000000));
    c.printf(c"1.0: %a\n",
         f64(1.0));
    c.printf(c"10.0: %a\n",
         f64(10.0));
    c.printf(c"10.5: %a\n",
         f64(10.5));
    c.printf(c"10.5e5: %a\n",
         f64(10.5e5));
    c.printf(c"10.5e+5: %a\n",
         f64(10.5e+5));
    c.printf(c"50.0e-2: %a\n",
         f64(50.0e-2));
    c.printf(c"50e-2: %a\n",
         f64(50e-2));

    c.printf(c"\n");

    c.printf(c"0x1.0: %a\n",
         f64(0x1.0));
    c.printf(c"0x10.0: %a\n",
         f64(0x10.0));
    c.printf(c"0x100.0: %a\n",
         f64(0x100.0));
    c.printf(c"0x103.0: %a\n",
         f64(0x103.0));
    c.printf(c"0x103.7: %a\n",
         f64(0x103.7));
    c.printf(c"0x103.70: %a\n",
         f64(0x103.70));
    c.printf(c"0x103.70p4: %a\n",
         f64(0x103.70p4));
    c.printf(c"0x103.70p5: %a\n",
         f64(0x103.70p5));
    c.printf(c"0x103.70p+5: %a\n",
         f64(0x103.70p+5));
    c.printf(c"0x103.70p-5: %a\n",
         f64(0x103.70p-5));

    c.printf(c"\n");

    c.printf(c"0b10100.00010e0: %a\n",
         f64(0b10100.00010e0));
    c.printf(c"0o10700.00010e0: %a\n",
         f64(0o10700.00010e0));

    return 0;
}
    )SOURCE", R"OUTPUT(
0: 0
320402575052271: 320402575052271
0x01236789abcdef: 320402575052271
0xffffffffffffffff: 18446744073709551615
0x000000ffffffffffffffff: 18446744073709551615
0o1777777777777777777777: 18446744073709551615
0o0000001777777777777777777777: 18446744073709551615
0b1111111111111111111111111111111111111111111111111111111111111111: 18446744073709551615
0b0000001111111111111111111111111111111111111111111111111111111111111111: 18446744073709551615

0.0: 0x0p+0
0e0: 0x0p+0
0.0e0: 0x0p+0
000000000000000000000000000000000000000000000000000000000.0e0: 0x0p+0
0.000000000000000000000000000000000000000000000000000000000e0: 0x0p+0
0.0e000000000000000000000000000000000000000000000000000000000: 0x0p+0
1.0: 0x1p+0
10.0: 0x1.4p+3
10.5: 0x1.5p+3
10.5e5: 0x1.0059p+20
10.5e+5: 0x1.0059p+20
50.0e-2: 0x1p-1
50e-2: 0x1p-1

0x1.0: 0x1p+0
0x10.0: 0x1p+4
0x100.0: 0x1p+8
0x103.0: 0x1.03p+8
0x103.7: 0x1.037p+8
0x103.70: 0x1.037p+8
0x103.70p4: 0x1.037p+12
0x103.70p5: 0x1.037p+13
0x103.70p+5: 0x1.037p+13
0x103.70p-5: 0x1.037p+3

0b10100.00010e0: 0x1.41p+4
0o10700.00010e0: 0x1.1c0001p+12
)OUTPUT");

    add_simple_case("order-independent declarations", R"SOURCE(
const io = @import("std").io;
const z = io.stdin_fileno;
const x : @typeof(y) = 1234;
const y : u16 = 5678;
pub fn main(args: [][]u8) -> %void {
    var x_local : i32 = print_ok(x);
}
fn print_ok(val: @typeof(x)) -> @typeof(foo) {
    %%io.stdout.printf("OK\n");
    return 0;
}
const foo : i32 = 0;
    )SOURCE", "OK\n");

    add_simple_case("for loops", R"SOURCE(
const io = @import("std").io;

pub fn main(args: [][]u8) -> %void {
    const array = []u8 {9, 8, 7, 6};
    for (array) |item| {
        %%io.stdout.print_u64(item);
        %%io.stdout.printf("\n");
    }
    for (array) |item, index| {
        %%io.stdout.print_i64(index);
        %%io.stdout.printf("\n");
    }
    const unknown_size: []u8 = array;
    for (unknown_size) |item| {
        %%io.stdout.print_u64(item);
        %%io.stdout.printf("\n");
    }
    for (unknown_size) |item, index| {
        %%io.stdout.print_i64(index);
        %%io.stdout.printf("\n");
    }
}
    )SOURCE", "9\n8\n7\n6\n0\n1\n2\n3\n9\n8\n7\n6\n0\n1\n2\n3\n");

    add_simple_case_libc("expose function pointer to C land", R"SOURCE(
const c = @c_import(@c_include("stdlib.h"));

export fn compare_fn(a: ?&const c_void, b: ?&const c_void) -> c_int {
    const a_int = (&i32)(a ?? unreachable{});
    const b_int = (&i32)(b ?? unreachable{});
    if (*a_int < *b_int) {
        -1
    } else if (*a_int > *b_int) {
        1
    } else {
        0
    }
}

export fn main(args: c_int, argv: &&u8) -> c_int {
    var array = []i32 { 1, 7, 3, 2, 0, 9, 4, 8, 6, 5 };

    c.qsort((&c_void)(&array[0]), c_ulong(array.len), @sizeof(i32), compare_fn);

    for (array) |item, i| {
        if (item != i) {
            c.abort();
        }
    }

    return 0;
}
    )SOURCE", "");



    add_simple_case_libc("casting between float and integer types", R"SOURCE(
const c = @c_import(@c_include("stdio.h"));
export fn main(argc: c_int, argv: &&u8) -> c_int {
    const small: f32 = 3.25;
    const x: f64 = small;
    const y = i32(x);
    const z = f64(y);
    c.printf(c"%.2f\n%d\n%.2f\n%.2f\n", x, y, z, f64(-0.4));
    return 0;
}
    )SOURCE", "3.25\n3\n3.00\n-0.40\n");


    add_simple_case("incomplete struct parameter top level decl", R"SOURCE(
const io = @import("std").io;
struct A {
    b: B,
}

struct B {
    c: C,
}

struct C {
    x: i32,

    fn d(c: C) {
        %%io.stdout.printf("OK\n");
    }
}

fn foo(a: A) {
    a.b.c.d();
}

pub fn main(args: [][]u8) -> %void {
    const a = A {
        .b = B {
            .c = C {
                .x = 13,
            },
        },
    };
    foo(a);
}

    )SOURCE", "OK\n");


    add_simple_case("same named methods in incomplete struct", R"SOURCE(
const io = @import("std").io;

struct Foo {
    field1: Bar,

    fn method(a: &Foo) -> bool { true }
}

struct Bar {
    field2: i32,

    fn method(b: &Bar) -> bool { true }
}

pub fn main(args: [][]u8) -> %void {
    const bar = Bar {.field2 = 13,};
    const foo = Foo {.field1 = bar,};
    if (!foo.method()) {
        %%io.stdout.printf("BAD\n");
    }
    if (!bar.method()) {
        %%io.stdout.printf("BAD\n");
    }
    %%io.stdout.printf("OK\n");
}
    )SOURCE", "OK\n");


    add_simple_case("defer with only fallthrough", R"SOURCE(
const io = @import("std").io;
pub fn main(args: [][]u8) -> %void {
    %%io.stdout.printf("before\n");
    defer %%io.stdout.printf("defer1\n");
    defer %%io.stdout.printf("defer2\n");
    defer %%io.stdout.printf("defer3\n");
    %%io.stdout.printf("after\n");
}
    )SOURCE", "before\nafter\ndefer3\ndefer2\ndefer1\n");


    add_simple_case("defer with return", R"SOURCE(
const io = @import("std").io;
pub fn main(args: [][]u8) -> %void {
    %%io.stdout.printf("before\n");
    defer %%io.stdout.printf("defer1\n");
    defer %%io.stdout.printf("defer2\n");
    if (args.len == 1) return;
    defer %%io.stdout.printf("defer3\n");
    %%io.stdout.printf("after\n");
}
    )SOURCE", "before\ndefer2\ndefer1\n");


    add_simple_case("%defer and it fails", R"SOURCE(
const io = @import("std").io;
pub fn main(args: [][]u8) -> %void {
    do_test() %% return;
}
fn do_test() -> %void {
    %%io.stdout.printf("before\n");
    defer %%io.stdout.printf("defer1\n");
    %defer %%io.stdout.printf("deferErr\n");
    %return its_gonna_fail();
    defer %%io.stdout.printf("defer3\n");
    %%io.stdout.printf("after\n");
}
error IToldYouItWouldFail;
fn its_gonna_fail() -> %void {
    return error.IToldYouItWouldFail;
}
    )SOURCE", "before\ndeferErr\ndefer1\n");


    add_simple_case("%defer and it passes", R"SOURCE(
const io = @import("std").io;
pub fn main(args: [][]u8) -> %void {
    do_test() %% return;
}
fn do_test() -> %void {
    %%io.stdout.printf("before\n");
    defer %%io.stdout.printf("defer1\n");
    %defer %%io.stdout.printf("deferErr\n");
    %return its_gonna_pass();
    defer %%io.stdout.printf("defer3\n");
    %%io.stdout.printf("after\n");
}
fn its_gonna_pass() -> %void { }
    )SOURCE", "before\nafter\ndefer3\ndefer1\n");


    {
        TestCase *tc = add_simple_case("@embed_file", R"SOURCE(
const foo_txt = @embed_file("foo.txt");
const io = @import("std").io;

pub fn main(args: [][]u8) -> %void {
    %%io.stdout.printf(foo_txt);
}
        )SOURCE", "1234\nabcd\n");

        add_source_file(tc, "foo.txt", "1234\nabcd\n");
    }
}


////////////////////////////////////////////////////////////////////////////////////

static void add_compile_failure_test_cases(void) {
    add_compile_fail_case("multiple function definitions", R"SOURCE(
fn a() {}
fn a() {}
    )SOURCE", 1, ".tmp_source.zig:3:1: error: redefinition of 'a'");

    add_compile_fail_case("bad directive", R"SOURCE(
#bogus1("")
extern fn b();
#bogus2("")
fn a() {}
    )SOURCE", 2, ".tmp_source.zig:2:1: error: invalid directive: 'bogus1'",
                 ".tmp_source.zig:4:1: error: invalid directive: 'bogus2'");

    add_compile_fail_case("unreachable with return", R"SOURCE(
fn a() -> unreachable {return;}
    )SOURCE", 1, ".tmp_source.zig:2:24: error: expected type 'unreachable', got 'void'");

    add_compile_fail_case("control reaches end of non-void function", R"SOURCE(
fn a() -> i32 {}
    )SOURCE", 1, ".tmp_source.zig:2:15: error: expected type 'i32', got 'void'");

    add_compile_fail_case("undefined function call", R"SOURCE(
fn a() {
    b();
}
    )SOURCE", 1, ".tmp_source.zig:3:5: error: use of undeclared identifier 'b'");

    add_compile_fail_case("wrong number of arguments", R"SOURCE(
fn a() {
    b(1);
}
fn b(a: i32, b: i32, c: i32) { }
    )SOURCE", 1, ".tmp_source.zig:3:6: error: expected 3 arguments, got 1");

    add_compile_fail_case("invalid type", R"SOURCE(
fn a() -> bogus {}
    )SOURCE", 1, ".tmp_source.zig:2:11: error: use of undeclared identifier 'bogus'");

    add_compile_fail_case("pointer to unreachable", R"SOURCE(
fn a() -> &unreachable {}
    )SOURCE", 1, ".tmp_source.zig:2:11: error: pointer to unreachable not allowed");

    add_compile_fail_case("unreachable code", R"SOURCE(
fn a() {
    return;
    b();
}

fn b() {}
    )SOURCE", 1, ".tmp_source.zig:4:5: error: unreachable code");

    add_compile_fail_case("bad import", R"SOURCE(
const bogus = @import("bogus-does-not-exist.zig");
    )SOURCE", 1, ".tmp_source.zig:2:15: error: unable to find 'bogus-does-not-exist.zig'");

    add_compile_fail_case("undeclared identifier", R"SOURCE(
fn a() {
    b +
    c
}
    )SOURCE", 2,
            ".tmp_source.zig:3:5: error: use of undeclared identifier 'b'",
            ".tmp_source.zig:4:5: error: use of undeclared identifier 'c'");

    add_compile_fail_case("parameter redeclaration", R"SOURCE(
fn f(a : i32, a : i32) {
}
    )SOURCE", 1, ".tmp_source.zig:2:15: error: redeclaration of variable 'a'");

    add_compile_fail_case("local variable redeclaration", R"SOURCE(
fn f() {
    const a : i32 = 0;
    const a = 0;
}
    )SOURCE", 1, ".tmp_source.zig:4:5: error: redeclaration of variable 'a'");

    add_compile_fail_case("local variable redeclares parameter", R"SOURCE(
fn f(a : i32) {
    const a = 0;
}
    )SOURCE", 1, ".tmp_source.zig:3:5: error: redeclaration of variable 'a'");

    add_compile_fail_case("variable has wrong type", R"SOURCE(
fn f() -> i32 {
    const a = c"a";
    a
}
    )SOURCE", 1, ".tmp_source.zig:4:5: error: expected type 'i32', got '&const u8'");

    add_compile_fail_case("if condition is bool, not int", R"SOURCE(
fn f() {
    if (0) {}
}
    )SOURCE", 1, ".tmp_source.zig:3:9: error: integer value 0 cannot be implicitly casted to type 'bool'");

    add_compile_fail_case("assign unreachable", R"SOURCE(
fn f() {
    const a = return;
}
    )SOURCE", 1, ".tmp_source.zig:3:5: error: variable initialization is unreachable");

    add_compile_fail_case("unreachable variable", R"SOURCE(
fn f() {
    const a : unreachable = return;
}
    )SOURCE", 1, ".tmp_source.zig:3:15: error: variable of type 'unreachable' not allowed");

    add_compile_fail_case("unreachable parameter", R"SOURCE(
fn f(a : unreachable) {}
    )SOURCE", 1, ".tmp_source.zig:2:10: error: parameter of type 'unreachable' not allowed");

    add_compile_fail_case("bad assignment target", R"SOURCE(
fn f() {
    3 = 3;
}
    )SOURCE", 1, ".tmp_source.zig:3:5: error: invalid assignment target");

    add_compile_fail_case("assign to constant variable", R"SOURCE(
fn f() {
    const a = 3;
    a = 4;
}
    )SOURCE", 1, ".tmp_source.zig:4:5: error: cannot assign to constant");

    add_compile_fail_case("use of undeclared identifier", R"SOURCE(
fn f() {
    b = 3;
}
    )SOURCE", 1, ".tmp_source.zig:3:5: error: use of undeclared identifier 'b'");

    add_compile_fail_case("const is a statement, not an expression", R"SOURCE(
fn f() {
    (const a = 0);
}
    )SOURCE", 1, ".tmp_source.zig:3:6: error: invalid token: 'const'");

    add_compile_fail_case("array access errors", R"SOURCE(
fn f() {
    var bad : bool = undefined;
    i[i] = i[i];
    bad[bad] = bad[bad];
}
    )SOURCE", 4, ".tmp_source.zig:4:5: error: use of undeclared identifier 'i'",
                 ".tmp_source.zig:4:7: error: use of undeclared identifier 'i'",
                 ".tmp_source.zig:5:8: error: array access of non-array",
                 ".tmp_source.zig:5:9: error: expected type 'isize', got 'bool'");

    add_compile_fail_case("variadic functions only allowed in extern", R"SOURCE(
fn f(...) {}
    )SOURCE", 1, ".tmp_source.zig:2:1: error: variadic arguments only allowed in extern function declarations");

    add_compile_fail_case("write to const global variable", R"SOURCE(
const x : i32 = 99;
fn f() {
    x = 1;
}
    )SOURCE", 1, ".tmp_source.zig:4:5: error: cannot assign to constant");


    add_compile_fail_case("missing else clause", R"SOURCE(
fn f(b: bool) {
    const x : i32 = if (b) { 1 };
    const y = if (b) { i32(1) };
}
    )SOURCE", 2, ".tmp_source.zig:3:21: error: expected type 'i32', got 'void'",
                 ".tmp_source.zig:4:15: error: incompatible types: 'i32' and 'void'");

    add_compile_fail_case("direct struct loop", R"SOURCE(
struct A { a : A, }
    )SOURCE", 1, ".tmp_source.zig:2:1: error: 'A' depends on itself");

    add_compile_fail_case("indirect struct loop", R"SOURCE(
struct A { b : B, }
struct B { c : C, }
struct C { a : A, }
    )SOURCE", 1, ".tmp_source.zig:2:1: error: 'A' depends on itself");

    add_compile_fail_case("invalid struct field", R"SOURCE(
struct A { x : i32, }
fn f() {
    var a : A = undefined;
    a.foo = 1;
    const y = a.bar;
}
    )SOURCE", 2,
            ".tmp_source.zig:5:6: error: no member named 'foo' in 'A'",
            ".tmp_source.zig:6:16: error: no member named 'bar' in 'A'");

    add_compile_fail_case("redefinition of struct", R"SOURCE(
struct A { x : i32, }
struct A { y : i32, }
    )SOURCE", 1, ".tmp_source.zig:3:1: error: redefinition of 'A'");

    add_compile_fail_case("redefinition of enums", R"SOURCE(
enum A {}
enum A {}
    )SOURCE", 1, ".tmp_source.zig:3:1: error: redefinition of 'A'");

    add_compile_fail_case("redefinition of global variables", R"SOURCE(
var a : i32 = 1;
var a : i32 = 2;
    )SOURCE", 1, ".tmp_source.zig:3:1: error: redeclaration of variable 'a'");

    add_compile_fail_case("byvalue struct on exported functions", R"SOURCE(
struct A { x : i32, }
export fn f(a : A) {}
    )SOURCE", 1, ".tmp_source.zig:3:13: error: byvalue struct parameters not yet supported on extern functions");

    add_compile_fail_case("duplicate field in struct value expression", R"SOURCE(
struct A {
    x : i32,
    y : i32,
    z : i32,
}
fn f() {
    const a = A {
        .z = 1,
        .y = 2,
        .x = 3,
        .z = 4,
    };
}
    )SOURCE", 1, ".tmp_source.zig:12:9: error: duplicate field");

    add_compile_fail_case("missing field in struct value expression", R"SOURCE(
struct A {
    x : i32,
    y : i32,
    z : i32,
}
fn f() {
    // we want the error on the '{' not the 'A' because
    // the A could be a complicated expression
    const a = A {
        .z = 4,
        .y = 2,
    };
}
    )SOURCE", 1, ".tmp_source.zig:10:17: error: missing field: 'x'");

    add_compile_fail_case("invalid field in struct value expression", R"SOURCE(
struct A {
    x : i32,
    y : i32,
    z : i32,
}
fn f() {
    const a = A {
        .z = 4,
        .y = 2,
        .foo = 42,
    };
}
    )SOURCE", 1, ".tmp_source.zig:11:9: error: no member named 'foo' in 'A'");

    add_compile_fail_case("invalid break expression", R"SOURCE(
fn f() {
    break;
}
    )SOURCE", 1, ".tmp_source.zig:3:5: error: 'break' expression outside loop");

    add_compile_fail_case("invalid continue expression", R"SOURCE(
fn f() {
    continue;
}
    )SOURCE", 1, ".tmp_source.zig:3:5: error: 'continue' expression outside loop");

    add_compile_fail_case("invalid maybe type", R"SOURCE(
fn f() {
    if (const x ?= true) { }
}
    )SOURCE", 1, ".tmp_source.zig:3:20: error: expected maybe type");

    add_compile_fail_case("cast unreachable", R"SOURCE(
fn f() -> i32 {
    i32(return 1)
}
    )SOURCE", 1, ".tmp_source.zig:3:8: error: invalid cast from type 'unreachable' to 'i32'");

    add_compile_fail_case("invalid builtin fn", R"SOURCE(
fn f() -> @bogus(foo) {
}
    )SOURCE", 1, ".tmp_source.zig:2:11: error: invalid builtin function: 'bogus'");

    add_compile_fail_case("top level decl dependency loop", R"SOURCE(
const a : @typeof(b) = 0;
const b : @typeof(a) = 0;
    )SOURCE", 1, ".tmp_source.zig:2:1: error: 'a' depends on itself");

    add_compile_fail_case("noalias on non pointer param", R"SOURCE(
fn f(noalias x: i32) {}
    )SOURCE", 1, ".tmp_source.zig:2:6: error: noalias on non-pointer parameter");

    add_compile_fail_case("struct init syntax for array", R"SOURCE(
const foo = []u16{.x = 1024,};
    )SOURCE", 1, ".tmp_source.zig:2:18: error: type '[]u16' does not support struct initialization syntax");

    add_compile_fail_case("type variables must be constant", R"SOURCE(
var foo = u8;
    )SOURCE", 1, ".tmp_source.zig:2:1: error: variable of type 'type' must be constant");

    add_compile_fail_case("variables shadowing types", R"SOURCE(
struct Foo {}
struct Bar {}

fn f(Foo: i32) {
    var Bar : i32 = undefined;
}
    )SOURCE", 4,
            ".tmp_source.zig:5:6: error: redefinition of 'Foo'",
            ".tmp_source.zig:2:1: note: previous definition is here",
            ".tmp_source.zig:6:5: error: redefinition of 'Bar'",
            ".tmp_source.zig:3:1: note: previous definition is here");

    add_compile_fail_case("multiple else prongs in a switch", R"SOURCE(
fn f(x: u32) {
    const value: bool = switch (x) {
        1234 => false,
        else => true,
        else => true,
    };
}
    )SOURCE", 1, ".tmp_source.zig:6:9: error: multiple else prongs in switch expression");

    add_compile_fail_case("global variable initializer must be constant expression", R"SOURCE(
extern fn foo() -> i32;
const x = foo();
    )SOURCE", 1, ".tmp_source.zig:3:11: error: global variable initializer requires constant expression");

    add_compile_fail_case("array concatenation with wrong type", R"SOURCE(
fn f(s: []u8) -> []u8 {
    s ++ "foo"
}
    )SOURCE", 1, ".tmp_source.zig:3:5: error: expected array or C string literal, got '[]u8'");

    add_compile_fail_case("non compile time array concatenation", R"SOURCE(
fn f(s: [10]u8) -> []u8 {
    s ++ "foo"
}
    )SOURCE", 1, ".tmp_source.zig:3:5: error: array concatenation requires constant expression");

    add_compile_fail_case("c_import with bogus include", R"SOURCE(
const c = @c_import(@c_include("bogus.h"));
    )SOURCE", 2, ".tmp_source.zig:2:11: error: C import failed",
                 ".h:1:10: note: 'bogus.h' file not found");

    add_compile_fail_case("address of number literal", R"SOURCE(
const x = 3;
const y = &x;
    )SOURCE", 1, ".tmp_source.zig:3:12: error: unable to get address of type '(integer literal)'");

    add_compile_fail_case("@typeof number literal", R"SOURCE(
const x = 3;
struct Foo {
    index: @typeof(x),
}
    )SOURCE", 1, ".tmp_source.zig:4:20: error: type '(integer literal)' not eligible for @typeof");

    add_compile_fail_case("integer overflow error", R"SOURCE(
const x : u8 = 300;
    )SOURCE", 1, ".tmp_source.zig:2:16: error: integer value 300 cannot be implicitly casted to type 'u8'");

    add_compile_fail_case("incompatible number literals", R"SOURCE(
const x = 2 == 2.0;
    )SOURCE", 1, ".tmp_source.zig:2:11: error: integer value 2 cannot be implicitly casted to type '(float literal)'");

    add_compile_fail_case("missing function call param", R"SOURCE(
struct Foo {
    a: i32,
    b: i32,

    fn member_a(foo: Foo) -> i32 {
        return foo.a;
    }
    fn member_b(foo: Foo) -> i32 {
        return foo.b;
    }
}

const member_fn_type = @typeof(Foo.member_a);
const members = []member_fn_type {
    Foo.member_a,
    Foo.member_b,
};

fn f(foo: Foo, index: i32) {
    const result = members[index]();
}
    )SOURCE", 1, ".tmp_source.zig:21:34: error: expected 1 arguments, got 0");

    add_compile_fail_case("missing function name and param name", R"SOURCE(
fn () {}
fn f(i32) {}
    )SOURCE", 2,
            ".tmp_source.zig:2:1: error: missing function name",
            ".tmp_source.zig:3:6: error: missing parameter name");

    add_compile_fail_case("wrong function type", R"SOURCE(
const fns = []fn(){ a, b, c };
fn a() -> i32 {0}
fn b() -> i32 {1}
fn c() -> i32 {2}
    )SOURCE", 3,
            ".tmp_source.zig:2:21: error: expected type 'fn()', got 'fn() -> i32'",
            ".tmp_source.zig:2:24: error: expected type 'fn()', got 'fn() -> i32'",
            ".tmp_source.zig:2:27: error: expected type 'fn()', got 'fn() -> i32'");

    add_compile_fail_case("extern function pointer mismatch", R"SOURCE(
const fns = [](fn(i32)->i32){ a, b, c };
pub fn a(x: i32) -> i32 {x + 0}
pub fn b(x: i32) -> i32 {x + 1}
export fn c(x: i32) -> i32 {x + 2}
    )SOURCE", 1, ".tmp_source.zig:2:37: error: expected type 'fn(i32) -> i32', got 'extern fn(i32) -> i32'");


    add_compile_fail_case("implicit cast from f64 to f32", R"SOURCE(
const x : f64 = 1.0;
const y : f32 = x;
    )SOURCE", 1, ".tmp_source.zig:3:17: error: expected type 'f32', got 'f64'");


    add_compile_fail_case("colliding invalid top level functions", R"SOURCE(
fn func() -> bogus {}
fn func() -> bogus {}
    )SOURCE", 2,
            ".tmp_source.zig:3:1: error: redefinition of 'func'",
            ".tmp_source.zig:2:14: error: use of undeclared identifier 'bogus'");


    add_compile_fail_case("bogus compile var", R"SOURCE(
const x = @compile_var("bogus");
    )SOURCE", 1, ".tmp_source.zig:2:24: error: unrecognized compile variable: 'bogus'");


    add_compile_fail_case("@const_eval", R"SOURCE(
fn a(x: i32) {
    const y = @const_eval(x);
}
    )SOURCE", 1, ".tmp_source.zig:3:27: error: unable to evaluate constant expression");

    add_compile_fail_case("non constant expression in array size outside function", R"SOURCE(
struct Foo {
    y: [get()]u8,
}
var global_var: isize = 1;
fn get() -> isize { global_var }
    )SOURCE", 1, ".tmp_source.zig:3:9: error: unable to evaluate constant expression");


    add_compile_fail_case("unnecessary if statement", R"SOURCE(
fn f() {
    if (true) { }
}
    )SOURCE", 1, ".tmp_source.zig:3:9: error: condition is always true; unnecessary if statement");


    add_compile_fail_case("addition with non numbers", R"SOURCE(
struct Foo {
    field: i32,
}
const x = Foo {.field = 1} + Foo {.field = 2};
    )SOURCE", 1, ".tmp_source.zig:5:28: error: invalid operands to binary expression: 'Foo' and 'Foo'");


    add_compile_fail_case("division by zero", R"SOURCE(
const lit_int_x = 1 / 0;
const lit_float_x = 1.0 / 0.0;
const int_x = i32(1) / i32(0);
const float_x = f32(1.0) / f32(0.0);
    )SOURCE", 4,
            ".tmp_source.zig:2:21: error: division by zero is undefined",
            ".tmp_source.zig:3:25: error: division by zero is undefined",
            ".tmp_source.zig:4:22: error: division by zero is undefined",
            ".tmp_source.zig:5:26: error: division by zero is undefined");


    add_compile_fail_case("missing switch prong", R"SOURCE(
enum Number {
    One,
    Two,
    Three,
    Four,
}
fn f(n: Number) -> i32 {
    switch (n) {
        One => 1,
        Two => 2,
        Three => 3,
    }
}
    )SOURCE", 1, ".tmp_source.zig:9:5: error: enumeration value 'Four' not handled in switch");

    add_compile_fail_case("import inside function body", R"SOURCE(
fn f() {
    const std = @import("std");
}
    )SOURCE", 1, ".tmp_source.zig:3:17: error: @import invalid inside function bodies");


    add_compile_fail_case("normal string with newline", R"SOURCE(
const foo = "a
b";
    )SOURCE", 1, ".tmp_source.zig:2:13: error: use raw string for multiline string literal");

    add_compile_fail_case("invalid comparison for function pointers", R"SOURCE(
fn foo() {}
const invalid = foo > foo;
    )SOURCE", 1, ".tmp_source.zig:3:21: error: operator not allowed for type 'fn()'");

    add_compile_fail_case("generic function instance with non-constant expression", R"SOURCE(
fn foo(inline x: i32, y: i32) -> i32 { return x + y; }
fn test1(a: i32, b: i32) -> i32 {
    return foo(a, b);
}
    )SOURCE", 1, ".tmp_source.zig:4:16: error: unable to evaluate constant expression for inline parameter");

    add_compile_fail_case("goto jumping into block", R"SOURCE(
fn f() {
    {
a_label:
    }
    goto a_label;
}
    )SOURCE", 2,
            ".tmp_source.zig:4:1: error: label 'a_label' defined but not used",
            ".tmp_source.zig:6:5: error: no label in scope named 'a_label'");

    add_compile_fail_case("goto jumping past a defer", R"SOURCE(
fn f(b: bool) {
    if (b) goto label;
    defer derp();
label:
}
fn derp(){}
    )SOURCE", 2,
            ".tmp_source.zig:3:12: error: no label in scope named 'label'",
            ".tmp_source.zig:5:1: error: label 'label' defined but not used");

    add_compile_fail_case("assign null to non-nullable pointer", R"SOURCE(
const a: &u8 = null;
    )SOURCE", 1, ".tmp_source.zig:2:16: error: expected maybe type, got '&u8'");

    add_compile_fail_case("indexing an array of size zero", R"SOURCE(
const array = []u8{};
fn foo() {
    const pointer = &array[0];
}
    )SOURCE", 1, ".tmp_source.zig:4:27: error: out of bounds array access");

    add_compile_fail_case("compile time division by zero", R"SOURCE(
const x = foo(0);
fn foo(x: i32) -> i32 {
    1 / x
}
    )SOURCE", 3,
            ".tmp_source.zig:3:1: error: function evaluation caused division by zero",
            ".tmp_source.zig:2:14: note: called from here",
            ".tmp_source.zig:4:7: note: division by zero here");

    add_compile_fail_case("branch on undefined value", R"SOURCE(
const x = if (undefined) true else false;
    )SOURCE", 1, ".tmp_source.zig:2:15: error: branch on undefined value");


    add_compile_fail_case("endless loop in function evaluation", R"SOURCE(
const seventh_fib_number = fibbonaci(7);
fn fibbonaci(x: i32) -> i32 {
    return fibbonaci(x - 1) + fibbonaci(x - 2);
}
    )SOURCE", 3,
            ".tmp_source.zig:3:1: error: function evaluation exceeded 1000 branches",
            ".tmp_source.zig:2:37: note: called from here",
            ".tmp_source.zig:4:40: note: quota exceeded here");

    add_compile_fail_case("@embed_file with bogus file", R"SOURCE(
const resource = @embed_file("bogus.txt");
    )SOURCE", 1, ".tmp_source.zig:2:18: error: unable to find './bogus.txt'");


    add_compile_fail_case("non-const expression in struct literal outside function", R"SOURCE(
struct Foo {
    x: i32,
}
const a = Foo {.x = get_it()};
extern fn get_it() -> i32;
    )SOURCE", 1, ".tmp_source.zig:5:27: error: unable to evaluate constant expression");

    add_compile_fail_case("non-const expression function call with struct return value outside function", R"SOURCE(
struct Foo {
    x: i32,
}
const a = get_it();
#static_eval_enable(false)
fn get_it() -> Foo { Foo {.x = 13} }
    )SOURCE", 1, ".tmp_source.zig:5:17: error: unable to evaluate constant expression");

    add_compile_fail_case("undeclared identifier error should mark fn as impure", R"SOURCE(
fn foo() {
    test_a_thing();
}
fn test_a_thing() {
    bad_fn_call();
}
    )SOURCE", 1, ".tmp_source.zig:6:5: error: use of undeclared identifier 'bad_fn_call'");

    add_compile_fail_case("illegal comparison of types", R"SOURCE(
fn bad_eql_1(a: []u8, b: []u8) -> bool {
    a == b
}
enum EnumWithData {
    One,
    Two: i32,
}
fn bad_eql_2(a: EnumWithData, b: EnumWithData) -> bool {
    a == b
}
    )SOURCE", 2,
            ".tmp_source.zig:3:7: error: operator not allowed for type '[]u8'",
            ".tmp_source.zig:10:7: error: operator not allowed for type 'EnumWithData'");

    add_compile_fail_case("non-const switch number literal", R"SOURCE(
fn foo() {
    const x = switch (bar()) {
        1, 2 => 1,
        3, 4 => 2,
        else => 3,
    };
}
#static_eval_enable(false)
fn bar() -> i32 { 2 }
    )SOURCE", 1, ".tmp_source.zig:3:15: error: unable to infer expression type");

    add_compile_fail_case("atomic orderings of cmpxchg", R"SOURCE(
fn f() {
    var x: i32 = 1234;
    while (!@cmpxchg(&x, 1234, 5678, AtomicOrder.Monotonic, AtomicOrder.SeqCst)) {}
    while (!@cmpxchg(&x, 1234, 5678, AtomicOrder.Unordered, AtomicOrder.Unordered)) {}
}
    )SOURCE", 2,
            ".tmp_source.zig:4:72: error: failure atomic ordering must be no stricter than success",
            ".tmp_source.zig:5:49: error: success atomic ordering must be Monotonic or stricter");

    add_compile_fail_case("negation overflow in function evaluation", R"SOURCE(
fn f() {
    const x = neg(-128);
}
fn neg(x: i8) -> i8 {
    -x
}
    )SOURCE", 3,
            ".tmp_source.zig:5:1: error: function evaluation caused overflow",
            ".tmp_source.zig:3:18: note: called from here",
            ".tmp_source.zig:6:5: note: overflow occurred here");

    add_compile_fail_case("add overflow in function evaluation", R"SOURCE(
fn f() {
    const x = add(65530, 10);
}
fn add(a: u16, b: u16) -> u16 {
    a + b
}
    )SOURCE", 3,
            ".tmp_source.zig:5:1: error: function evaluation caused overflow",
            ".tmp_source.zig:3:18: note: called from here",
            ".tmp_source.zig:6:7: note: overflow occurred here");


    add_compile_fail_case("sub overflow in function evaluation", R"SOURCE(
fn f() {
    const x = sub(10, 20);
}
fn sub(a: u16, b: u16) -> u16 {
    a - b
}
    )SOURCE", 3,
            ".tmp_source.zig:5:1: error: function evaluation caused overflow",
            ".tmp_source.zig:3:18: note: called from here",
            ".tmp_source.zig:6:7: note: overflow occurred here");

    add_compile_fail_case("mul overflow in function evaluation", R"SOURCE(
fn f() {
    const x = mul(300, 6000);
}
fn mul(a: u16, b: u16) -> u16 {
    a * b
}
    )SOURCE", 3,
            ".tmp_source.zig:5:1: error: function evaluation caused overflow",
            ".tmp_source.zig:3:18: note: called from here",
            ".tmp_source.zig:6:7: note: overflow occurred here");

    add_compile_fail_case("add incompatible int types", R"SOURCE(
fn add(x: i8w, y: i32) {
    const z = x + y;
}
    )SOURCE", 1, ".tmp_source.zig:3:17: error: incompatible types: 'i8w' and 'i32'");

    add_compile_fail_case("truncate sign mismatch", R"SOURCE(
fn f() {
    const x: u32 = 10;
    @truncate(i8, x);
}
    )SOURCE", 1, ".tmp_source.zig:4:19: error: expected signed integer type, got 'u32'");

    add_compile_fail_case("truncate same bit count", R"SOURCE(
fn f() {
    const x: i8 = 10;
    @truncate(i8, x);
}
    )SOURCE", 1, ".tmp_source.zig:4:19: error: type 'i8' has same or fewer bits than destination type 'i8'");

    add_compile_fail_case("truncate same bit count", R"SOURCE(
fn f() {
    %return something();
}
fn something() -> %void { }
    )SOURCE", 2,
            ".tmp_source.zig:3:5: error: %return statement in function with return type 'void'",
            ".tmp_source.zig:2:8: note: function return type here");

    add_compile_fail_case("wrong return type for main", R"SOURCE(
pub fn main(args: [][]u8) { }
    )SOURCE", 1, ".tmp_source.zig:2:27: error: expected return type of main to be '%void', instead is 'void'");


    add_compile_fail_case("invalid pointer for var type", R"SOURCE(
extern fn ext() -> isize;
var bytes: [ext()]u8 = undefined;
fn f() {
    for (bytes) |*b, i| {
        *b = u8(i);
    }
}
    )SOURCE", 1, ".tmp_source.zig:3:13: error: unable to evaluate constant expression");

    add_compile_fail_case("export function with inline parameter", R"SOURCE(
export fn foo(inline x: i32, y: i32) -> i32{
    x + y
}
    )SOURCE", 1, ".tmp_source.zig:2:15: error: inline parameter not allowed in extern function");

    add_compile_fail_case("extern function with inline parameter", R"SOURCE(
extern fn foo(inline x: i32, y: i32) -> i32;
fn f() -> i32 {
    foo(1, 2)
}
    )SOURCE", 1, ".tmp_source.zig:2:15: error: inline parameter not allowed in extern function");

    /* TODO
    add_compile_fail_case("inline export function", R"SOURCE(
export inline fn foo(x: i32, y: i32) -> i32{
    x + y
}
    )SOURCE", 1, ".tmp_source.zig:2:1: error: extern functions cannot be inline");
    */

}

//////////////////////////////////////////////////////////////////////////////

static void add_debug_safety_test_cases(void) {
    add_debug_safety_case("out of bounds slice access", R"SOURCE(
pub fn main(args: [][]u8) -> %void {
    const a = []i32{1, 2, 3, 4};
    baz(bar(a));
}
#static_eval_enable(false)
fn bar(a: []i32) -> i32 {
    a[4]
}
#static_eval_enable(false)
fn baz(a: i32) {}
    )SOURCE");

    add_debug_safety_case("integer addition overflow", R"SOURCE(
error Whatever;
pub fn main(args: [][]u8) -> %void {
    const x = add(65530, 10);
    if (x == 0) return error.Whatever;
}
#static_eval_enable(false)
fn add(a: u16, b: u16) -> u16 {
    a + b
}
    )SOURCE");

    add_debug_safety_case("integer subtraction overflow", R"SOURCE(
error Whatever;
pub fn main(args: [][]u8) -> %void {
    const x = sub(10, 20);
    if (x == 0) return error.Whatever;
}
#static_eval_enable(false)
fn sub(a: u16, b: u16) -> u16 {
    a - b
}
    )SOURCE");

    add_debug_safety_case("integer multiplication overflow", R"SOURCE(
error Whatever;
pub fn main(args: [][]u8) -> %void {
    const x = mul(300, 6000);
    if (x == 0) return error.Whatever;
}
#static_eval_enable(false)
fn mul(a: u16, b: u16) -> u16 {
    a * b
}
    )SOURCE");

    add_debug_safety_case("integer negation overflow", R"SOURCE(
error Whatever;
pub fn main(args: [][]u8) -> %void {
    const x = neg(-32768);
    if (x == 0) return error.Whatever;
}
#static_eval_enable(false)
fn neg(a: i16) -> i16 {
    -a
}
    )SOURCE");

    add_debug_safety_case("signed shift left overflow", R"SOURCE(
error Whatever;
pub fn main(args: [][]u8) -> %void {
    const x = shl(-16385, 1);
    if (x == 0) return error.Whatever;
}
#static_eval_enable(false)
fn shl(a: i16, b: i16) -> i16 {
    a << b
}
    )SOURCE");

    add_debug_safety_case("unsigned shift left overflow", R"SOURCE(
error Whatever;
pub fn main(args: [][]u8) -> %void {
    const x = shl(0b0010111111111111, 3);
    if (x == 0) return error.Whatever;
}
#static_eval_enable(false)
fn shl(a: u16, b: u16) -> u16 {
    a << b
}
    )SOURCE");

    add_debug_safety_case("integer division by zero", R"SOURCE(
error Whatever;
pub fn main(args: [][]u8) -> %void {
    const x = div0(999, 0);
}
#static_eval_enable(false)
fn div0(a: i32, b: i32) -> i32 {
    a / b
}
    )SOURCE");

    add_debug_safety_case("exact division failure", R"SOURCE(
error Whatever;
pub fn main(args: [][]u8) -> %void {
    const x = div_exact(10, 3);
    if (x == 0) return error.Whatever;
}
#static_eval_enable(false)
fn div_exact(a: i32, b: i32) -> i32 {
    @div_exact(a, b)
}
    )SOURCE");

    add_debug_safety_case("cast []u8 to bigger slice of wrong size", R"SOURCE(
error Whatever;
pub fn main(args: [][]u8) -> %void {
    const x = widen_slice([]u8{1, 2, 3, 4, 5});
    if (x.len == 0) return error.Whatever;
}
#static_eval_enable(false)
fn widen_slice(slice: []u8) -> []i32 {
    ([]i32)(slice)
}
    )SOURCE");

    add_debug_safety_case("value does not fit in shortening cast", R"SOURCE(
error Whatever;
pub fn main(args: [][]u8) -> %void {
    const x = shorten_cast(200);
    if (x == 0) return error.Whatever;
}
#static_eval_enable(false)
fn shorten_cast(x: i32) -> i8 {
    i8(x)
}
    )SOURCE");

    add_debug_safety_case("signed integer not fitting in cast to unsigned integer", R"SOURCE(
error Whatever;
pub fn main(args: [][]u8) -> %void {
    const x = unsigned_cast(-10);
    if (x == 0) return error.Whatever;
}
#static_eval_enable(false)
fn unsigned_cast(x: i32) -> u32 {
    u32(x)
}
    )SOURCE");

}

//////////////////////////////////////////////////////////////////////////////

static void add_parseh_test_cases(void) {
    add_parseh_case("simple data types", R"SOURCE(
#include <stdint.h>
int foo(char a, unsigned char b, signed char c);
int foo(char a, unsigned char b, signed char c); // test a duplicate prototype
void bar(uint8_t a, uint16_t b, uint32_t c, uint64_t d);
void baz(int8_t a, int16_t b, int32_t c, int64_t d);
    )SOURCE", 3,
            "pub extern fn foo(a: u8, b: u8, c: i8) -> c_int;",
            "pub extern fn bar(a: u8, b: u16, c: u32, d: u64);",
            "pub extern fn baz(a: i8, b: i16, c: i32, d: i64);");

    add_parseh_case("noreturn attribute", R"SOURCE(
void foo(void) __attribute__((noreturn));
    )SOURCE", 1, R"OUTPUT(pub extern fn foo() -> unreachable;)OUTPUT");

    add_parseh_case("enums", R"SOURCE(
enum Foo {
    FooA,
    FooB,
    Foo1,
};
    )SOURCE", 3, R"(export enum enum_Foo {
    A,
    B,
    @"1",
})", R"(pub const FooA = enum_Foo.A;
pub const FooB = enum_Foo.B;
pub const Foo1 = enum_Foo.@"1";)",
            R"(pub const Foo = enum_Foo;)");

    add_parseh_case("restrict -> noalias", R"SOURCE(
void foo(void *restrict bar, void *restrict);
    )SOURCE", 1, R"OUTPUT(pub extern fn foo(noalias bar: ?&c_void, noalias arg1: ?&c_void);)OUTPUT");

    add_parseh_case("simple struct", R"SOURCE(
struct Foo {
    int x;
    char *y;
};
    )SOURCE", 2,
            R"OUTPUT(export struct struct_Foo {
    x: c_int,
    y: ?&u8,
})OUTPUT", R"OUTPUT(pub const Foo = struct_Foo;)OUTPUT");

    add_parseh_case("qualified struct and enum", R"SOURCE(
struct Foo {
    int x;
    int y;
};
enum Bar {
    BarA,
    BarB,
};
void func(struct Foo *a, enum Bar **b);
    )SOURCE", 5, R"OUTPUT(export struct struct_Foo {
    x: c_int,
    y: c_int,
})OUTPUT", R"OUTPUT(
export enum enum_Bar {
    A,
    B,
})OUTPUT", R"OUTPUT(pub const BarA = enum_Bar.A;
pub const BarB = enum_Bar.B;)OUTPUT",
            "pub extern fn func(a: ?&struct_Foo, b: ?&?&enum_Bar);",
    R"OUTPUT(pub const Foo = struct_Foo;
pub const Bar = enum_Bar;)OUTPUT");

    add_parseh_case("constant size array", R"SOURCE(
void func(int array[20]);
    )SOURCE", 1, "pub extern fn func(array: ?&c_int);");


    add_parseh_case("self referential struct with function pointer", R"SOURCE(
struct Foo {
    void (*derp)(struct Foo *foo);
};
    )SOURCE", 2, R"OUTPUT(export struct struct_Foo {
    derp: ?extern fn(?&struct_Foo),
})OUTPUT", R"OUTPUT(pub const Foo = struct_Foo;)OUTPUT");


    add_parseh_case("struct prototype used in func", R"SOURCE(
struct Foo;
struct Foo *some_func(struct Foo *foo, int x);
    )SOURCE", 2, R"OUTPUT(pub type struct_Foo = u8;
pub extern fn some_func(foo: ?&struct_Foo, x: c_int) -> ?&struct_Foo;)OUTPUT",
        R"OUTPUT(pub const Foo = struct_Foo;)OUTPUT");


    add_parseh_case("#define a char literal", R"SOURCE(
#define A_CHAR  'a'
    )SOURCE", 1, R"OUTPUT(pub const A_CHAR = 'a';)OUTPUT");


    add_parseh_case("#define an unsigned integer literal", R"SOURCE(
#define CHANNEL_COUNT 24
    )SOURCE", 1, R"OUTPUT(pub const CHANNEL_COUNT = 24;)OUTPUT");


    add_parseh_case("#define referencing another #define", R"SOURCE(
#define THING2 THING1
#define THING1 1234
    )SOURCE", 2,
            "pub const THING1 = 1234;",
            "pub const THING2 = THING1;");


    add_parseh_case("variables", R"SOURCE(
extern int extern_var;
static const int int_var = 13;
    )SOURCE", 2,
            "pub extern var extern_var: c_int;",
            "pub const int_var: c_int = 13;");


    add_parseh_case("circular struct definitions", R"SOURCE(
struct Bar;

struct Foo {
    struct Bar *next;
};

struct Bar {
    struct Foo *next;
};
    )SOURCE", 2,
            R"SOURCE(export struct struct_Bar {
    next: ?&struct_Foo,
})SOURCE",
            R"SOURCE(export struct struct_Foo {
    next: ?&struct_Bar,
})SOURCE");


    add_parseh_case("typedef void", R"SOURCE(
typedef void Foo;
Foo fun(Foo *a);
    )SOURCE", 2,
            "pub const Foo = c_void;",
            "pub extern fn fun(a: ?&c_void);");

    add_parseh_case("generate inline func for #define global extern fn", R"SOURCE(
extern void (*fn_ptr)(void);
#define foo fn_ptr
    )SOURCE", 2,
            "pub extern var fn_ptr: ?extern fn();",
            R"SOURCE(pub inline fn foo() {
    (??fn_ptr)();
})SOURCE");


    add_parseh_case("#define string", R"SOURCE(
#define  foo  "a string"
    )SOURCE", 1, "pub const foo = c\"a string\";");

    add_parseh_case("__cdecl doesn't mess up function pointers", R"SOURCE(
void foo(void (__cdecl *fn_ptr)(void));
    )SOURCE", 1, "pub extern fn foo(fn_ptr: ?extern fn());");

    add_parseh_case("comment after integer literal", R"SOURCE(
#define SDL_INIT_VIDEO 0x00000020  /**< SDL_INIT_VIDEO implies SDL_INIT_EVENTS */
    )SOURCE", 1, "pub const SDL_INIT_VIDEO = 32;");

    add_parseh_case("zig keywords in C code", R"SOURCE(
struct type {
    int defer;
};
    )SOURCE", 2, R"(export struct struct_type {
    @"defer": c_int,
})", R"(pub const @"type" = struct_type;)");

    add_parseh_case("macro defines string literal with octal", R"SOURCE(
#define FOO "aoeu\023 derp"
#define FOO2 "aoeu\0234 derp"
#define FOO_CHAR '\077'
    )SOURCE", 3,
            R"(pub const FOO = c"aoeu\x13 derp")",
            R"(pub const FOO2 = c"aoeu\x134 derp")",
            R"(pub const FOO_CHAR = '\x3f')");
}

static void run_self_hosted_test(bool is_release_mode) {
    Buf zig_stderr = BUF_INIT;
    Buf zig_stdout = BUF_INIT;
    ZigList<const char *> args = {0};
    args.append("test");
    args.append("../test/self_hosted.zig");
    if (is_release_mode) {
        args.append("--release");
    }
    Termination term;
    os_exec_process(zig_exe, args, &term, &zig_stderr, &zig_stdout);

    if (term.how != TerminationIdClean || term.code != 0) {
        printf("\nSelf-hosted tests failed:\n");
        printf("./zig");
        for (int i = 0; i < args.length; i += 1) {
            printf(" %s", args.at(i));
        }
        printf("\n%s\n", buf_ptr(&zig_stderr));
        exit(1);
    }
}

static void add_self_hosted_tests(void) {
    {
        TestCase *test_case = allocate<TestCase>(1);
        test_case->case_name = "self hosted tests (debug)";
        test_case->is_self_hosted = true;
        test_case->is_release_mode = false;
        test_cases.append(test_case);
    }
    {
        TestCase *test_case = allocate<TestCase>(1);
        test_case->case_name = "self hosted tests (release)";
        test_case->is_self_hosted = true;
        test_case->is_release_mode = true;
        test_cases.append(test_case);
    }
}

static void print_compiler_invocation(TestCase *test_case) {
    printf("%s", zig_exe);
    for (int i = 0; i < test_case->compiler_args.length; i += 1) {
        printf(" %s", test_case->compiler_args.at(i));
    }
    printf("\n");
}

static void print_exe_invocation(TestCase *test_case) {
    printf("%s", tmp_exe_path);
    for (int i = 0; i < test_case->program_args.length; i += 1) {
        printf(" %s", test_case->program_args.at(i));
    }
    printf("\n");
}

static void run_test(TestCase *test_case) {
    if (test_case->is_self_hosted) {
        return run_self_hosted_test(test_case->is_release_mode);
    }

    for (int i = 0; i < test_case->source_files.length; i += 1) {
        TestSourceFile *test_source = &test_case->source_files.at(i);
        os_write_file(
                buf_create_from_str(test_source->relative_path),
                buf_create_from_str(test_source->source_code));
    }

    Buf zig_stderr = BUF_INIT;
    Buf zig_stdout = BUF_INIT;
    int err;
    Termination term;
    if ((err = os_exec_process(zig_exe, test_case->compiler_args, &term, &zig_stderr, &zig_stdout))) {
        fprintf(stderr, "Unable to exec %s: %s\n", zig_exe, err_str(err));
    }

    if (!test_case->is_parseh && test_case->compile_errors.length) {
        if (term.how != TerminationIdClean || term.code != 0) {
            for (int i = 0; i < test_case->compile_errors.length; i += 1) {
                const char *err_text = test_case->compile_errors.at(i);
                if (!strstr(buf_ptr(&zig_stderr), err_text)) {
                    printf("\n");
                    printf("========= Expected this compile error: =========\n");
                    printf("%s\n", err_text);
                    printf("================================================\n");
                    print_compiler_invocation(test_case);
                    printf("%s\n", buf_ptr(&zig_stderr));
                    exit(1);
                }
            }
            return; // success
        } else {
            printf("\nCompile failed with return code 0 (Expected failure):\n");
            print_compiler_invocation(test_case);
            printf("%s\n", buf_ptr(&zig_stderr));
            exit(1);
        }
    }

    if (term.how != TerminationIdClean || term.code != 0) {
        printf("\nCompile failed:\n");
        print_compiler_invocation(test_case);
        printf("%s\n", buf_ptr(&zig_stderr));
        exit(1);
    }

    if (test_case->is_parseh) {
        if (buf_len(&zig_stderr) > 0) {
            printf("\nparseh emitted warnings:\n");
            print_compiler_invocation(test_case);
            printf("%s\n", buf_ptr(&zig_stderr));
            exit(1);
        }

        for (int i = 0; i < test_case->compile_errors.length; i += 1) {
            const char *output = test_case->compile_errors.at(i);

            if (!strstr(buf_ptr(&zig_stdout), output)) {
                printf("\n");
                printf("========= Expected this output: =========\n");
                printf("%s\n", output);
                printf("================================================\n");
                print_compiler_invocation(test_case);
                printf("%s\n", buf_ptr(&zig_stdout));
                exit(1);
            }
        }
    } else {
        Buf program_stderr = BUF_INIT;
        Buf program_stdout = BUF_INIT;
        os_exec_process(tmp_exe_path, test_case->program_args, &term, &program_stderr, &program_stdout);

        if (test_case->is_debug_safety) {
            int debug_trap_signal = 5;
            if (term.how != TerminationIdSignaled || term.code != debug_trap_signal) {
                if (term.how == TerminationIdClean) {
                    printf("\nProgram expected to hit debug trap (signal %d) but exited with return code %d\n",
                            debug_trap_signal, term.code);
                } else if (term.how == TerminationIdSignaled) {
                    printf("\nProgram expected to hit debug trap (signal %d) but signaled with code %d\n",
                            debug_trap_signal, term.code);
                } else {
                    printf("\nProgram expected to hit debug trap (signal %d) exited in an unexpected way\n",
                            debug_trap_signal);
                }
                print_compiler_invocation(test_case);
                print_exe_invocation(test_case);
                exit(1);
            }
        } else {
            if (term.how != TerminationIdClean || term.code != 0) {
                printf("\nProgram exited with error\n");
                print_compiler_invocation(test_case);
                print_exe_invocation(test_case);
                printf("%s\n", buf_ptr(&program_stderr));
                exit(1);
            }

            if (!buf_eql_str(&program_stdout, test_case->output)) {
                printf("\n");
                print_compiler_invocation(test_case);
                print_exe_invocation(test_case);
                printf("==== Test failed. Expected output: ====\n");
                printf("%s\n", test_case->output);
                printf("========= Actual output: ==============\n");
                printf("%s\n", buf_ptr(&program_stdout));
                printf("=======================================\n");
                exit(1);
            }
        }
    }

    for (int i = 0; i < test_case->source_files.length; i += 1) {
        TestSourceFile *test_source = &test_case->source_files.at(i);
        remove(test_source->relative_path);
    }
}

static void run_all_tests(bool reverse) {
    if (reverse) {
        for (int i = test_cases.length - 1; i >= 0; i -= 1) {
            TestCase *test_case = test_cases.at(i);
            printf("Test %d/%d %s...", i + 1, test_cases.length, test_case->case_name);
            run_test(test_case);
            printf("OK\n");
        }
    } else {
        for (int i = 0; i < test_cases.length; i += 1) {
            TestCase *test_case = test_cases.at(i);
            printf("Test %d/%d %s...", i + 1, test_cases.length, test_case->case_name);
            run_test(test_case);
            printf("OK\n");
        }
    }
    printf("%d tests passed.\n", test_cases.length);
}

static void cleanup(void) {
    remove(tmp_source_path);
    remove(tmp_h_path);
    remove(tmp_exe_path);
}

static int usage(const char *arg0) {
    fprintf(stderr, "Usage: %s [--reverse]\n", arg0);
    return 1;
}

int main(int argc, char **argv) {
    bool reverse = false;
    for (int i = 1; i < argc; i += 1) {
        if (strcmp(argv[i], "--reverse") == 0) {
            reverse = true;
        } else {
            return usage(argv[0]);
        }
    }
    add_compiling_test_cases();
    add_debug_safety_test_cases();
    add_compile_failure_test_cases();
    add_parseh_test_cases();
    add_self_hosted_tests();
    run_all_tests(reverse);
    cleanup();
}

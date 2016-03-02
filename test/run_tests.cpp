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

    add_simple_case("params", R"SOURCE(
const io = @import("std").io;

fn add(a: i32, b: i32) -> i32 {
    a + b
}

pub fn main(args: [][]u8) -> %void {
    if (add(22, 11) == 33) {
        %%io.stdout.printf("pass\n");
    }
}
    )SOURCE", "pass\n");

    add_simple_case("void parameters", R"SOURCE(
const io = @import("std").io;

pub fn main(args: [][]u8) -> %void {
    void_fun(1, void{}, 2);
}

fn void_fun(a : i32, b : void, c : i32) {
    const v = b;
    const vv : void = if (a == 1) {v} else {};
    if (a + c == 3) { %%io.stdout.printf("OK\n"); }
    return vv;
}
    )SOURCE", "OK\n");

    add_simple_case("mutable local variables", R"SOURCE(
const io = @import("std").io;

pub fn main(args: [][]u8) -> %void {
    var zero : i32 = 0;
    if (zero == 0) { %%io.stdout.printf("zero\n"); }

    var i = i32(0);
    while (i != 3) {
        %%io.stdout.printf("loop\n");
        i += 1;
    }
}
    )SOURCE", "zero\nloop\nloop\nloop\n");

    add_simple_case("arrays", R"SOURCE(
const io = @import("std").io;

pub fn main(args: [][]u8) -> %void {
    var array : [5]i32 = undefined;

    var i : i32 = 0;
    while (i < 5) {
        array[i] = i + 1;
        i = array[i];
    }

    i = 0;
    var accumulator = i32(0);
    while (i < 5) {
        accumulator += array[i];

        i += 1;
    }

    if (accumulator == 15) {
        %%io.stdout.printf("OK\n");
    }

    if (get_array_len(array) != 5) {
        %%io.stdout.printf("BAD\n");
    }
}
fn get_array_len(a: []i32) -> isize {
    a.len
}
    )SOURCE", "OK\n");


    add_simple_case("hello world without libc", R"SOURCE(
const io = @import("std").io;

pub fn main(args: [][]u8) -> %void {
    %%io.stdout.printf("Hello, world!\n");
}
    )SOURCE", "Hello, world!\n");


    add_simple_case("short circuit", R"SOURCE(
const io = @import("std").io;

pub fn main(args: [][]u8) -> %void {
    if (true || { %%io.stdout.printf("BAD 1\n"); false }) {
      %%io.stdout.printf("OK 1\n");
    }
    if (false || { %%io.stdout.printf("OK 2\n"); false }) {
      %%io.stdout.printf("BAD 2\n");
    }

    if (true && { %%io.stdout.printf("OK 3\n"); false }) {
      %%io.stdout.printf("BAD 3\n");
    }
    if (false && { %%io.stdout.printf("BAD 4\n"); false }) {
    } else {
      %%io.stdout.printf("OK 4\n");
    }
}
    )SOURCE", "OK 1\nOK 2\nOK 3\nOK 4\n");

    add_simple_case("modify operators", R"SOURCE(
const io = @import("std").io;

pub fn main(args: [][]u8) -> %void {
    var i : i32 = 0;
    i += 5;  if (i != 5)  { %%io.stdout.printf("BAD +=\n"); }
    i -= 2;  if (i != 3)  { %%io.stdout.printf("BAD -=\n"); }
    i *= 20; if (i != 60) { %%io.stdout.printf("BAD *=\n"); }
    i /= 3;  if (i != 20) { %%io.stdout.printf("BAD /=\n"); }
    i %= 11; if (i != 9)  { %%io.stdout.printf("BAD %=\n"); }
    i <<= 1; if (i != 18) { %%io.stdout.printf("BAD <<=\n"); }
    i >>= 2; if (i != 4)  { %%io.stdout.printf("BAD >>=\n"); }
    i = 6;
    i &= 5;  if (i != 4)  { %%io.stdout.printf("BAD &=\n"); }
    i ^= 6;  if (i != 2)  { %%io.stdout.printf("BAD ^=\n"); }
    i = 6;
    i |= 3;  if (i != 7)  { %%io.stdout.printf("BAD |=\n"); }

    %%io.stdout.printf("OK\n");
}
    )SOURCE", "OK\n");

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

    add_simple_case("structs", R"SOURCE(
const io = @import("std").io;

pub fn main(args: [][]u8) -> %void {
    var foo : Foo = undefined;
    @memset(&foo, 0, @sizeof(Foo));
    foo.a += 1;
    foo.b = foo.a == 1;
    test_foo(foo);
    test_mutation(&foo);
    if (foo.c != 100) {
        %%io.stdout.printf("BAD\n");
    }
    test_point_to_self();
    test_byval_assign();
    test_initializer();
    %%io.stdout.printf("OK\n");
}
struct Foo {
    a : i32,
    b : bool,
    c : f32,
}
fn test_foo(foo : Foo) {
    if (!foo.b) {
        %%io.stdout.printf("BAD\n");
    }
}
fn test_mutation(foo : &Foo) {
    foo.c = 100;
}
struct Node {
    val: Val,
    next: &Node,
}

struct Val {
    x: i32,
}
fn test_point_to_self() {
    var root : Node = undefined;
    root.val.x = 1;

    var node : Node = undefined;
    node.next = &root;
    node.val.x = 2;

    root.next = &node;

    if (node.next.next.next.val.x != 1) {
        %%io.stdout.printf("BAD\n");
    }
}
fn test_byval_assign() {
    var foo1 : Foo = undefined;
    var foo2 : Foo = undefined;

    foo1.a = 1234;

    if (foo2.a != 0) { %%io.stdout.printf("BAD\n"); }

    foo2 = foo1;

    if (foo2.a != 1234) { %%io.stdout.printf("BAD - byval assignment failed\n"); }
}
fn test_initializer() {
    const val = Val { .x = 42 };
    if (val.x != 42) { %%io.stdout.printf("BAD\n"); }
}
    )SOURCE", "OK\n");

    add_simple_case("global variables", R"SOURCE(
const io = @import("std").io;

const g1 : i32 = 1233 + 1;
var g2 : i32 = 0;

pub fn main(args: [][]u8) -> %void {
    if (g2 != 0) { %%io.stdout.printf("BAD\n"); }
    g2 = g1;
    if (g2 != 1234) { %%io.stdout.printf("BAD\n"); }
    %%io.stdout.printf("OK\n");
}
    )SOURCE", "OK\n");

    add_simple_case("while loop", R"SOURCE(
const io = @import("std").io;
pub fn main(args: [][]u8) -> %void {
    var i : i32 = 0;
    while (i < 4) {
        %%io.stdout.printf("loop\n");
        i += 1;
    }
    g();
}
fn g() -> i32 {
    return f();
}
fn f() -> i32 {
    while (true) {
        return 0;
    }
}
    )SOURCE", "loop\nloop\nloop\nloop\n");

    add_simple_case("continue and break", R"SOURCE(
const io = @import("std").io;
pub fn main(args: [][]u8) -> %void {
    var i : i32 = 0;
    while (true) {
        %%io.stdout.printf("loop\n");
        i += 1;
        if (i < 4) {
            continue;
        }
        break;
    }
}
    )SOURCE", "loop\nloop\nloop\nloop\n");

    add_simple_case("implicit cast after unreachable", R"SOURCE(
const io = @import("std").io;
pub fn main(args: [][]u8) -> %void {
    const x = outer();
    if (x == 1234) {
        %%io.stdout.printf("OK\n");
    }
}
fn inner() -> i32 { 1234 }
fn outer() -> isize {
    return inner();
}
    )SOURCE", "OK\n");

    add_simple_case("@sizeof() and @typeof()", R"SOURCE(
const io = @import("std").io;
const x: u16 = 13;
const z: @typeof(x) = 19;
pub fn main(args: [][]u8) -> %void {
    const y: @typeof(x) = 120;
    %%io.stdout.print_u64(@sizeof(@typeof(y)));
    %%io.stdout.printf("\n");
}
    )SOURCE", "2\n");

    add_simple_case("member functions", R"SOURCE(
const io = @import("std").io;
struct Rand {
    seed: u32,
    pub fn get_seed(r: Rand) -> u32 {
        r.seed
    }
}
pub fn main(args: [][]u8) -> %void {
    const r = Rand {.seed = 1234};
    if (r.get_seed() != 1234) {
        %%io.stdout.printf("BAD seed\n");
    }
    %%io.stdout.printf("OK\n");
}
    )SOURCE", "OK\n");

    add_simple_case("pointer dereferencing", R"SOURCE(
const io = @import("std").io;

pub fn main(args: [][]u8) -> %void {
    var x = i32(3);
    const y = &x;

    *y += 1;

    if (x != 4) {
        %%io.stdout.printf("BAD\n");
    }
    if (*y != 4) {
        %%io.stdout.printf("BAD\n");
    }
    %%io.stdout.printf("OK\n");
}
    )SOURCE", "OK\n");

    add_simple_case("constant expressions", R"SOURCE(
const io = @import("std").io;

const ARRAY_SIZE : i8 = 20;

pub fn main(args: [][]u8) -> %void {
    var array : [ARRAY_SIZE]u8 = undefined;
    %%io.stdout.print_u64(@sizeof(@typeof(array)));
    %%io.stdout.printf("\n");
}
    )SOURCE", "20\n");

    add_simple_case("@min_value() and @max_value()", R"SOURCE(
const io = @import("std").io;
pub fn main(args: [][]u8) -> %void {
    %%io.stdout.printf("max u8: ");
    %%io.stdout.print_u64(@max_value(u8));
    %%io.stdout.printf("\n");

    %%io.stdout.printf("max u16: ");
    %%io.stdout.print_u64(@max_value(u16));
    %%io.stdout.printf("\n");

    %%io.stdout.printf("max u32: ");
    %%io.stdout.print_u64(@max_value(u32));
    %%io.stdout.printf("\n");

    %%io.stdout.printf("max u64: ");
    %%io.stdout.print_u64(@max_value(u64));
    %%io.stdout.printf("\n");

    %%io.stdout.printf("max i8: ");
    %%io.stdout.print_i64(@max_value(i8));
    %%io.stdout.printf("\n");

    %%io.stdout.printf("max i16: ");
    %%io.stdout.print_i64(@max_value(i16));
    %%io.stdout.printf("\n");

    %%io.stdout.printf("max i32: ");
    %%io.stdout.print_i64(@max_value(i32));
    %%io.stdout.printf("\n");

    %%io.stdout.printf("max i64: ");
    %%io.stdout.print_i64(@max_value(i64));
    %%io.stdout.printf("\n");

    %%io.stdout.printf("min u8: ");
    %%io.stdout.print_u64(@min_value(u8));
    %%io.stdout.printf("\n");

    %%io.stdout.printf("min u16: ");
    %%io.stdout.print_u64(@min_value(u16));
    %%io.stdout.printf("\n");

    %%io.stdout.printf("min u32: ");
    %%io.stdout.print_u64(@min_value(u32));
    %%io.stdout.printf("\n");

    %%io.stdout.printf("min u64: ");
    %%io.stdout.print_u64(@min_value(u64));
    %%io.stdout.printf("\n");

    %%io.stdout.printf("min i8: ");
    %%io.stdout.print_i64(@min_value(i8));
    %%io.stdout.printf("\n");

    %%io.stdout.printf("min i16: ");
    %%io.stdout.print_i64(@min_value(i16));
    %%io.stdout.printf("\n");

    %%io.stdout.printf("min i32: ");
    %%io.stdout.print_i64(@min_value(i32));
    %%io.stdout.printf("\n");

    %%io.stdout.printf("min i64: ");
    %%io.stdout.print_i64(@min_value(i64));
    %%io.stdout.printf("\n");
}
    )SOURCE",
        "max u8: 255\n"
        "max u16: 65535\n"
        "max u32: 4294967295\n"
        "max u64: 18446744073709551615\n"
        "max i8: 127\n"
        "max i16: 32767\n"
        "max i32: 2147483647\n"
        "max i64: 9223372036854775807\n"
        "min u8: 0\n"
        "min u16: 0\n"
        "min u32: 0\n"
        "min u64: 0\n"
        "min i8: -128\n"
        "min i16: -32768\n"
        "min i32: -2147483648\n"
        "min i64: -9223372036854775808\n");


    add_simple_case("else if expression", R"SOURCE(
const io = @import("std").io;
pub fn main(args: [][]u8) -> %void {
    if (f(1) == 1) {
        %%io.stdout.printf("OK\n");
    }
}
fn f(c: u8) -> u8 {
    if (c == 0) {
        0
    } else if (c == 1) {
        1
    } else {
        2
    }
}
    )SOURCE", "OK\n");

    add_simple_case("overflow intrinsics", R"SOURCE(
const io = @import("std").io;
pub fn main(args: [][]u8) -> %void {
    var result: u8 = undefined;
    if (!@add_with_overflow(u8, 250, 100, &result)) {
        %%io.stdout.printf("BAD\n");
    }
    if (@add_with_overflow(u8, 100, 150, &result)) {
        %%io.stdout.printf("BAD\n");
    }
    if (result != 250) {
        %%io.stdout.printf("BAD\n");
    }
    %%io.stdout.printf("OK\n");
}
    )SOURCE", "OK\n");

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

    add_simple_case("nested arrays", R"SOURCE(
const io = @import("std").io;

pub fn main(args: [][]u8) -> %void {
    const array_of_strings = [][]u8 {"hello", "this", "is", "my", "thing"};
    for (array_of_strings) |str| {
        %%io.stdout.printf(str);
        %%io.stdout.printf("\n");
    }
}
    )SOURCE", "hello\nthis\nis\nmy\nthing\n");

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

    add_simple_case("function pointers", R"SOURCE(
const io = @import("std").io;

pub fn main(args: [][]u8) -> %void {
    const fns = []@typeof(fn1) { fn1, fn2, fn3, fn4, };
    for (fns) |f| {
        %%io.stdout.print_u64(f());
        %%io.stdout.printf("\n");
    }
}

fn fn1() -> u32 {5}
fn fn2() -> u32 {6}
fn fn3() -> u32 {7}
fn fn4() -> u32 {8}
    )SOURCE", "5\n6\n7\n8\n");

    add_simple_case("statically initialized struct", R"SOURCE(
const io = @import("std").io;
struct Foo {
    x: i32,
    y: bool,
}
var foo = Foo { .x = 13, .y = true, };
pub fn main(args: [][]u8) -> %void {
    foo.x += 1;
    if (foo.x != 14) {
        %%io.stdout.printf("BAD\n");
    }

    %%io.stdout.printf("OK\n");
}
    )SOURCE", "OK\n");

    add_simple_case("statically initialized array literal", R"SOURCE(
const io = @import("std").io;
const x = []u8{1,2,3,4};
pub fn main(args: [][]u8) -> %void {
    const y : [4]u8 = x;
    if (y[3] != 4) {
        %%io.stdout.printf("BAD\n");
    }

    %%io.stdout.printf("OK\n");
}
    )SOURCE", "OK\n");

    add_simple_case("return with implicit cast from while loop", R"SOURCE(
const io = @import("std").io;
pub fn main(args: [][]u8) -> %void {
    while (true) {
        %%io.stdout.printf("OK\n");
        return;
    }
}
    )SOURCE", "OK\n");

    add_simple_case("return struct byval from function", R"SOURCE(
const io = @import("std").io;
struct Foo {
    x: i32,
    y: i32,
}
fn make_foo(x: i32, y: i32) -> Foo {
    Foo {
        .x = x,
        .y = y,
    }
}
pub fn main(args: [][]u8) -> %void {
    const foo = make_foo(1234, 5678);
    if (foo.y != 5678) {
        %%io.stdout.printf("BAD\n");
    }
    %%io.stdout.printf("OK\n");
}
    )SOURCE", "OK\n");

    add_simple_case("%% binary operator", R"SOURCE(
const io = @import("std").io;
error ItBroke;
fn g(x: bool) -> %isize {
    if (x) {
        error.ItBroke
    } else {
        10
    }
}
pub fn main(args: [][]u8) -> %void {
    const a = g(true) %% 3;
    const b = g(false) %% 3;
    if (a != 3) {
        %%io.stdout.printf("BAD\n");
    }
    if (b != 10) {
        %%io.stdout.printf("BAD\n");
    }
    %%io.stdout.printf("OK\n");
}
    )SOURCE", "OK\n");

    add_simple_case("string concatenation", R"SOURCE(
const io = @import("std").io;
pub fn main(args: [][]u8) -> %void {
    %%io.stdout.printf("OK" ++ " IT " ++ "WORKED\n");
}
    )SOURCE", "OK IT WORKED\n");

    add_simple_case("constant struct with negation", R"SOURCE(
const io = @import("std").io;
struct Vertex {
    x: f32,
    y: f32,
    r: f32,
    g: f32,
    b: f32,
}
const vertices = []Vertex {
    Vertex { .x = -0.6, .y = -0.4, .r = 1.0, .g = 0.0, .b = 0.0 },
    Vertex { .x =  0.6, .y = -0.4, .r = 0.0, .g = 1.0, .b = 0.0 },
    Vertex { .x =  0.0, .y =  0.6, .r = 0.0, .g = 0.0, .b = 1.0 },
};
pub fn main(args: [][]u8) -> %void {
    if (vertices[0].x != -0.6) {
        %%io.stdout.printf("BAD\n");
    }
    %%io.stdout.printf("OK\n");
}
    )SOURCE", "OK\n");

    add_simple_case("int to ptr cast", R"SOURCE(
const io = @import("std").io;
pub fn main(args: [][]u8) -> %void {
    const x = isize(13);
    const y = (&u8)(x);
    const z = usize(y);
    if (z != 13) {
        %%io.stdout.printf("BAD\n");
    }
    %%io.stdout.printf("OK\n");
}
    )SOURCE", "OK\n");

    add_simple_case("pointer to void return type", R"SOURCE(
const io = @import("std").io;
const x = void{};
fn f() -> &void {
    %%io.stdout.printf("OK\n");
    return &x;
}
pub fn main(args: [][]u8) -> %void {
    const a = f();
    return *a;
}
    )SOURCE", "OK\n");

    add_simple_case("unwrap simple value from error", R"SOURCE(
const io = @import("std").io;
fn do() -> %isize {
    13
}

pub fn main(args: [][]u8) -> %void {
    const i = %%do();
    if (i != 13) {
        %%io.stdout.printf("BAD\n");
    }
    %%io.stdout.printf("OK\n");
}
    )SOURCE", "OK\n");

    add_simple_case("store member function in variable", R"SOURCE(
const io = @import("std").io;
struct Foo {
    x: i32,
    fn member(foo: Foo) -> i32 { foo.x }
}
pub fn main(args: [][]u8) -> %void {
    const instance = Foo { .x = 1234, };
    const member_fn = Foo.member;
    const result = member_fn(instance);
    if (result != 1234) {
        %%io.stdout.printf("BAD\n");
    }
    %%io.stdout.printf("OK\n");
}
    )SOURCE", "OK\n");

    add_simple_case("call member function directly", R"SOURCE(
const io = @import("std").io;
struct Foo {
    x: i32,
    fn member(foo: Foo) -> i32 { foo.x }
}
pub fn main(args: [][]u8) -> %void {
    const instance = Foo { .x = 1234, };
    const result = Foo.member(instance);
    if (result != 1234) {
        %%io.stdout.printf("BAD\n");
    }
    %%io.stdout.printf("OK\n");
}
    )SOURCE", "OK\n");

    add_simple_case("call result of if else expression", R"SOURCE(
const io = @import("std").io;
fn a() -> []u8 { "a\n" }
fn b() -> []u8 { "b\n" }
fn f(x: bool) {
    %%io.stdout.printf((if (x) a else b)());
}
pub fn main(args: [][]u8) -> %void {
    f(true);
    f(false);
}
    )SOURCE", "a\nb\n");


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


    add_simple_case("const expression eval handling of variables", R"SOURCE(
const io = @import("std").io;
pub fn main(args: [][]u8) -> %void {
    var x = true;
    while (x) {
        x = false;
    }
    %%io.stdout.printf("OK\n");
}
    )SOURCE", "OK\n");


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
    )SOURCE", 1, ".tmp_source.zig:2:1: error: variadic arguments only allowed in extern functions");

    add_compile_fail_case("write to const global variable", R"SOURCE(
const x : i32 = 99;
fn f() {
    x = 1;
}
    )SOURCE", 1, ".tmp_source.zig:4:5: error: cannot assign to constant");


    add_compile_fail_case("missing else clause", R"SOURCE(
fn f() {
    const x : i32 = if (true) { 1 };
    const y = if (true) { i32(1) };
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

    add_compile_fail_case("non compile time string concatenation", R"SOURCE(
fn f(s: []u8) -> []u8 {
    s ++ "foo"
}
    )SOURCE", 1, ".tmp_source.zig:3:5: error: string concatenation requires constant expression");

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
fn get() -> isize { 1 }
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
    )SOURCE", 1, R"OUTPUT(export enum enum_Foo {
    A,
    B,
    _1,
}
pub const FooA = enum_Foo.A;
pub const FooB = enum_Foo.B;
pub const Foo1 = enum_Foo._1;)OUTPUT",
            R"OUTPUT(pub const Foo = enum_Foo;)OUTPUT");

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
    )SOURCE", 3, R"OUTPUT(export struct struct_Foo {
    x: c_int,
    y: c_int,
}
export enum enum_Bar {
    A,
    B,
}
pub const BarA = enum_Bar.A;
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


    add_parseh_case("overide previous #define", R"SOURCE(
#define A_CHAR 'a'
#define A_CHAR 'b'
    )SOURCE", 1, "pub const A_CHAR = 'b';");


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
    (??fn_ptr)()
})SOURCE");


    add_parseh_case("#define string", R"SOURCE(
#define  foo  "a string"
    )SOURCE", 1, "pub const foo = c\"a string\";");

    add_parseh_case("__cdecl doesn't mess up function pointers", R"SOURCE(
void foo(void (__cdecl *fn_ptr)(void));
    )SOURCE", 1, "pub extern fn foo(fn_ptr: ?extern fn());");
}

static void run_self_hosted_test(void) {
    Buf zig_stderr = BUF_INIT;
    Buf zig_stdout = BUF_INIT;
    int return_code;
    ZigList<const char *> args = {0};
    args.append("test");
    args.append("../test/self_hosted.zig");
    os_exec_process(zig_exe, args, &return_code, &zig_stderr, &zig_stdout);

    if (return_code) {
        printf("\nSelf-hosted tests failed:\n");
        printf("./zig test ../test/self_hosted.zig\n");
        printf("%s\n", buf_ptr(&zig_stderr));
        exit(1);
    }
}

static void add_self_hosted_tests(void) {
    TestCase *test_case = allocate<TestCase>(1);
    test_case->case_name = "self hosted tests";
    test_case->is_self_hosted = true;
    test_cases.append(test_case);
}

static void print_compiler_invocation(TestCase *test_case) {
    printf("%s", zig_exe);
    for (int i = 0; i < test_case->compiler_args.length; i += 1) {
        printf(" %s", test_case->compiler_args.at(i));
    }
    printf("\n");
}

static void run_test(TestCase *test_case) {
    if (test_case->is_self_hosted) {
        return run_self_hosted_test();
    }

    for (int i = 0; i < test_case->source_files.length; i += 1) {
        TestSourceFile *test_source = &test_case->source_files.at(i);
        os_write_file(
                buf_create_from_str(test_source->relative_path),
                buf_create_from_str(test_source->source_code));
    }

    Buf zig_stderr = BUF_INIT;
    Buf zig_stdout = BUF_INIT;
    int return_code;
    int err;
    if ((err = os_exec_process(zig_exe, test_case->compiler_args, &return_code, &zig_stderr, &zig_stdout))) {
        fprintf(stderr, "Unable to exec %s: %s\n", zig_exe, err_str(err));
    }

    if (!test_case->is_parseh && test_case->compile_errors.length) {
        if (return_code) {
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

    if (return_code != 0) {
        printf("\nCompile failed with return code %d:\n", return_code);
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
        os_exec_process(tmp_exe_path, test_case->program_args, &return_code, &program_stderr, &program_stdout);

        if (return_code != 0) {
            printf("\nProgram exited with return code %d:\n", return_code);
            print_compiler_invocation(test_case);
            printf("%s", tmp_exe_path);
            for (int i = 0; i < test_case->program_args.length; i += 1) {
                printf(" %s", test_case->program_args.at(i));
            }
            printf("\n");
            printf("%s\n", buf_ptr(&program_stderr));
            exit(1);
        }

        if (!buf_eql_str(&program_stdout, test_case->output)) {
            printf("\n");
            print_compiler_invocation(test_case);
            printf("%s", tmp_exe_path);
            for (int i = 0; i < test_case->program_args.length; i += 1) {
                printf(" %s", test_case->program_args.at(i));
            }
            printf("\n");
            printf("==== Test failed. Expected output: ====\n");
            printf("%s\n", test_case->output);
            printf("========= Actual output: ==============\n");
            printf("%s\n", buf_ptr(&program_stdout));
            printf("=======================================\n");
            exit(1);
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
    add_compile_failure_test_cases();
    add_parseh_test_cases();
    add_self_hosted_tests();
    run_all_tests(reverse);
    cleanup();
}

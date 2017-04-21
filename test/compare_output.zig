const os = @import("std").os;
const tests = @import("tests.zig");

pub fn addCases(cases: &tests.CompareOutputContext) {
    cases.addC("hello world with libc",
        \\const c = @cImport(@cInclude("stdio.h"));
        \\export fn main(argc: c_int, argv: &&u8) -> c_int {
        \\    _ = c.puts(c"Hello, world!");
        \\    return 0;
        \\}
    , "Hello, world!" ++ os.line_sep);

    cases.addCase({
        var tc = cases.create("multiple files with private function",
            \\use @import("std").io;
            \\use @import("foo.zig");
            \\
            \\pub fn main() -> %void {
            \\    privateFunction();
            \\    %%stdout.printf("OK 2\n");
            \\}
            \\
            \\fn privateFunction() {
            \\    printText();
            \\}
        , "OK 1\nOK 2\n");

        tc.addSourceFile("foo.zig",
            \\use @import("std").io;
            \\
            \\// purposefully conflicting function with main.zig
            \\// but it's private so it should be OK
            \\fn privateFunction() {
            \\    %%stdout.printf("OK 1\n");
            \\}
            \\
            \\pub fn printText() {
            \\    privateFunction();
            \\}
        );

        tc
    });

    cases.addCase({
        var tc = cases.create("import segregation",
            \\use @import("foo.zig");
            \\use @import("bar.zig");
            \\
            \\pub fn main() -> %void {
            \\    foo_function();
            \\    bar_function();
            \\}
        , "OK\nOK\n");

        tc.addSourceFile("foo.zig",
            \\use @import("std").io;
            \\pub fn foo_function() {
            \\    %%stdout.printf("OK\n");
            \\}
        );

        tc.addSourceFile("bar.zig",
            \\use @import("other.zig");
            \\use @import("std").io;
            \\
            \\pub fn bar_function() {
            \\    if (foo_function()) {
            \\        %%stdout.printf("OK\n");
            \\    }
            \\}
        );

        tc.addSourceFile("other.zig",
            \\pub fn foo_function() -> bool {
            \\    // this one conflicts with the one from foo
            \\    return true;
            \\}
        );

        tc
    });

    cases.addCase({
        var tc = cases.create("two files use import each other",
            \\use @import("a.zig");
            \\
            \\pub fn main() -> %void {
            \\    ok();
            \\}
        , "OK\n");

        tc.addSourceFile("a.zig",
            \\use @import("b.zig");
            \\const io = @import("std").io;
            \\
            \\pub const a_text = "OK\n";
            \\
            \\pub fn ok() {
            \\    %%io.stdout.printf(b_text);
            \\}
        );

        tc.addSourceFile("b.zig",
            \\use @import("a.zig");
            \\
            \\pub const b_text = a_text;
        );

        tc
    });

    cases.add("hello world without libc",
        \\const io = @import("std").io;
        \\
        \\pub fn main() -> %void {
        \\    %%io.stdout.printf("Hello, world!\n{d4} {x3} {c}\n", u32(12), u16(0x12), u8('a'));
        \\}
    , "Hello, world!\n0012 012 a\n");

    cases.addC("number literals",
        \\const c = @cImport(@cInclude("stdio.h"));
        \\
        \\export fn main(argc: c_int, argv: &&u8) -> c_int {
        \\    _ = c.printf(c"0: %llu\n",
        \\             u64(0));
        \\    _ = c.printf(c"320402575052271: %llu\n",
        \\         u64(320402575052271));
        \\    _ = c.printf(c"0x01236789abcdef: %llu\n",
        \\         u64(0x01236789abcdef));
        \\    _ = c.printf(c"0xffffffffffffffff: %llu\n",
        \\         u64(0xffffffffffffffff));
        \\    _ = c.printf(c"0x000000ffffffffffffffff: %llu\n",
        \\         u64(0x000000ffffffffffffffff));
        \\    _ = c.printf(c"0o1777777777777777777777: %llu\n",
        \\         u64(0o1777777777777777777777));
        \\    _ = c.printf(c"0o0000001777777777777777777777: %llu\n",
        \\         u64(0o0000001777777777777777777777));
        \\    _ = c.printf(c"0b1111111111111111111111111111111111111111111111111111111111111111: %llu\n",
        \\         u64(0b1111111111111111111111111111111111111111111111111111111111111111));
        \\    _ = c.printf(c"0b0000001111111111111111111111111111111111111111111111111111111111111111: %llu\n",
        \\         u64(0b0000001111111111111111111111111111111111111111111111111111111111111111));
        \\
        \\    _ = c.printf(c"\n");
        \\
        \\    _ = c.printf(c"0.0: %a\n",
        \\         f64(0.0));
        \\    _ = c.printf(c"0e0: %a\n",
        \\         f64(0e0));
        \\    _ = c.printf(c"0.0e0: %a\n",
        \\         f64(0.0e0));
        \\    _ = c.printf(c"000000000000000000000000000000000000000000000000000000000.0e0: %a\n",
        \\         f64(000000000000000000000000000000000000000000000000000000000.0e0));
        \\    _ = c.printf(c"0.000000000000000000000000000000000000000000000000000000000e0: %a\n",
        \\         f64(0.000000000000000000000000000000000000000000000000000000000e0));
        \\    _ = c.printf(c"0.0e000000000000000000000000000000000000000000000000000000000: %a\n",
        \\         f64(0.0e000000000000000000000000000000000000000000000000000000000));
        \\    _ = c.printf(c"1.0: %a\n",
        \\         f64(1.0));
        \\    _ = c.printf(c"10.0: %a\n",
        \\         f64(10.0));
        \\    _ = c.printf(c"10.5: %a\n",
        \\         f64(10.5));
        \\    _ = c.printf(c"10.5e5: %a\n",
        \\         f64(10.5e5));
        \\    _ = c.printf(c"10.5e+5: %a\n",
        \\         f64(10.5e+5));
        \\    _ = c.printf(c"50.0e-2: %a\n",
        \\         f64(50.0e-2));
        \\    _ = c.printf(c"50e-2: %a\n",
        \\         f64(50e-2));
        \\
        \\    _ = c.printf(c"\n");
        \\
        \\    _ = c.printf(c"0x1.0: %a\n",
        \\         f64(0x1.0));
        \\    _ = c.printf(c"0x10.0: %a\n",
        \\         f64(0x10.0));
        \\    _ = c.printf(c"0x100.0: %a\n",
        \\         f64(0x100.0));
        \\    _ = c.printf(c"0x103.0: %a\n",
        \\         f64(0x103.0));
        \\    _ = c.printf(c"0x103.7: %a\n",
        \\         f64(0x103.7));
        \\    _ = c.printf(c"0x103.70: %a\n",
        \\         f64(0x103.70));
        \\    _ = c.printf(c"0x103.70p4: %a\n",
        \\         f64(0x103.70p4));
        \\    _ = c.printf(c"0x103.70p5: %a\n",
        \\         f64(0x103.70p5));
        \\    _ = c.printf(c"0x103.70p+5: %a\n",
        \\         f64(0x103.70p+5));
        \\    _ = c.printf(c"0x103.70p-5: %a\n",
        \\         f64(0x103.70p-5));
        \\
        \\    _ = c.printf(c"\n");
        \\
        \\    _ = c.printf(c"0b10100.00010e0: %a\n",
        \\         f64(0b10100.00010e0));
        \\    _ = c.printf(c"0o10700.00010e0: %a\n",
        \\         f64(0o10700.00010e0));
        \\
        \\    return 0;
        \\}
    ,
        \\0: 0
        \\320402575052271: 320402575052271
        \\0x01236789abcdef: 320402575052271
        \\0xffffffffffffffff: 18446744073709551615
        \\0x000000ffffffffffffffff: 18446744073709551615
        \\0o1777777777777777777777: 18446744073709551615
        \\0o0000001777777777777777777777: 18446744073709551615
        \\0b1111111111111111111111111111111111111111111111111111111111111111: 18446744073709551615
        \\0b0000001111111111111111111111111111111111111111111111111111111111111111: 18446744073709551615
        \\
        \\0.0: 0x0p+0
        \\0e0: 0x0p+0
        \\0.0e0: 0x0p+0
        \\000000000000000000000000000000000000000000000000000000000.0e0: 0x0p+0
        \\0.000000000000000000000000000000000000000000000000000000000e0: 0x0p+0
        \\0.0e000000000000000000000000000000000000000000000000000000000: 0x0p+0
        \\1.0: 0x1p+0
        \\10.0: 0x1.4p+3
        \\10.5: 0x1.5p+3
        \\10.5e5: 0x1.0059p+20
        \\10.5e+5: 0x1.0059p+20
        \\50.0e-2: 0x1p-1
        \\50e-2: 0x1p-1
        \\
        \\0x1.0: 0x1p+0
        \\0x10.0: 0x1p+4
        \\0x100.0: 0x1p+8
        \\0x103.0: 0x1.03p+8
        \\0x103.7: 0x1.037p+8
        \\0x103.70: 0x1.037p+8
        \\0x103.70p4: 0x1.037p+12
        \\0x103.70p5: 0x1.037p+13
        \\0x103.70p+5: 0x1.037p+13
        \\0x103.70p-5: 0x1.037p+3
        \\
        \\0b10100.00010e0: 0x1.41p+4
        \\0o10700.00010e0: 0x1.1c0001p+12
        \\
    );

    cases.add("order-independent declarations",
        \\const io = @import("std").io;
        \\const z = io.stdin_fileno;
        \\const x : @typeOf(y) = 1234;
        \\const y : u16 = 5678;
        \\pub fn main() -> %void {
        \\    var x_local : i32 = print_ok(x);
        \\}
        \\fn print_ok(val: @typeOf(x)) -> @typeOf(foo) {
        \\    %%io.stdout.printf("OK\n");
        \\    return 0;
        \\}
        \\const foo : i32 = 0;
    , "OK\n");

    cases.addC("expose function pointer to C land",
        \\const c = @cImport(@cInclude("stdlib.h"));
        \\
        \\export fn compare_fn(a: ?&const c_void, b: ?&const c_void) -> c_int {
        \\    const a_int = @ptrCast(&i32, a ?? unreachable);
        \\    const b_int = @ptrCast(&i32, b ?? unreachable);
        \\    if (*a_int < *b_int) {
        \\        -1
        \\    } else if (*a_int > *b_int) {
        \\        1
        \\    } else {
        \\        c_int(0)
        \\    }
        \\}
        \\
        \\export fn main() -> c_int {
        \\    var array = []u32 { 1, 7, 3, 2, 0, 9, 4, 8, 6, 5 };
        \\
        \\    c.qsort(@ptrCast(&c_void, &array[0]), c_ulong(array.len), @sizeOf(i32), compare_fn);
        \\
        \\    for (array) |item, i| {
        \\        if (item != i) {
        \\            c.abort();
        \\        }
        \\    }
        \\
        \\    return 0;
        \\}
    , "");

    cases.addC("casting between float and integer types",
        \\const c = @cImport(@cInclude("stdio.h"));
        \\export fn main(argc: c_int, argv: &&u8) -> c_int {
        \\    const small: f32 = 3.25;
        \\    const x: f64 = small;
        \\    const y = i32(x);
        \\    const z = f64(y);
        \\    _ = c.printf(c"%.2f\n%d\n%.2f\n%.2f\n", x, y, z, f64(-0.4));
        \\    return 0;
        \\}
    , "3.25\n3\n3.00\n-0.40\n");

    cases.add("same named methods in incomplete struct",
        \\const io = @import("std").io;
        \\
        \\const Foo = struct {
        \\    field1: Bar,
        \\
        \\    fn method(a: &const Foo) -> bool { true }
        \\};
        \\
        \\const Bar = struct {
        \\    field2: i32,
        \\
        \\    fn method(b: &const Bar) -> bool { true }
        \\};
        \\
        \\pub fn main() -> %void {
        \\    const bar = Bar {.field2 = 13,};
        \\    const foo = Foo {.field1 = bar,};
        \\    if (!foo.method()) {
        \\        %%io.stdout.printf("BAD\n");
        \\    }
        \\    if (!bar.method()) {
        \\        %%io.stdout.printf("BAD\n");
        \\    }
        \\    %%io.stdout.printf("OK\n");
        \\}
    , "OK\n");

    cases.add("defer with only fallthrough",
        \\const io = @import("std").io;
        \\pub fn main() -> %void {
        \\    %%io.stdout.printf("before\n");
        \\    defer %%io.stdout.printf("defer1\n");
        \\    defer %%io.stdout.printf("defer2\n");
        \\    defer %%io.stdout.printf("defer3\n");
        \\    %%io.stdout.printf("after\n");
        \\}
    , "before\nafter\ndefer3\ndefer2\ndefer1\n");

    cases.add("defer with return",
        \\const io = @import("std").io;
        \\const os = @import("std").os;
        \\pub fn main() -> %void {
        \\    %%io.stdout.printf("before\n");
        \\    defer %%io.stdout.printf("defer1\n");
        \\    defer %%io.stdout.printf("defer2\n");
        \\    if (os.args.count() == 1) return;
        \\    defer %%io.stdout.printf("defer3\n");
        \\    %%io.stdout.printf("after\n");
        \\}
    , "before\ndefer2\ndefer1\n");

    cases.add("%defer and it fails",
        \\const io = @import("std").io;
        \\pub fn main() -> %void {
        \\    do_test() %% return;
        \\}
        \\fn do_test() -> %void {
        \\    %%io.stdout.printf("before\n");
        \\    defer %%io.stdout.printf("defer1\n");
        \\    %defer %%io.stdout.printf("deferErr\n");
        \\    %return its_gonna_fail();
        \\    defer %%io.stdout.printf("defer3\n");
        \\    %%io.stdout.printf("after\n");
        \\}
        \\error IToldYouItWouldFail;
        \\fn its_gonna_fail() -> %void {
        \\    return error.IToldYouItWouldFail;
        \\}
    , "before\ndeferErr\ndefer1\n");

    cases.add("%defer and it passes",
        \\const io = @import("std").io;
        \\pub fn main() -> %void {
        \\    do_test() %% return;
        \\}
        \\fn do_test() -> %void {
        \\    %%io.stdout.printf("before\n");
        \\    defer %%io.stdout.printf("defer1\n");
        \\    %defer %%io.stdout.printf("deferErr\n");
        \\    %return its_gonna_pass();
        \\    defer %%io.stdout.printf("defer3\n");
        \\    %%io.stdout.printf("after\n");
        \\}
        \\fn its_gonna_pass() -> %void { }
    , "before\nafter\ndefer3\ndefer1\n");

    cases.addCase({
        var tc = cases.create("@embedFile",
            \\const foo_txt = @embedFile("foo.txt");
            \\const io = @import("std").io;
            \\
            \\pub fn main() -> %void {
            \\    %%io.stdout.printf(foo_txt);
            \\}
        , "1234\nabcd\n");

        tc.addSourceFile("foo.txt", "1234\nabcd\n");

        tc
    });
}

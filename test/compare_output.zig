const builtin = @import("builtin");
const std = @import("std");
const os = std.os;
const tests = @import("tests.zig");

pub fn addCases(cases: *tests.CompareOutputContext) void {
    cases.addC("hello world with libc",
        \\const c = @cImport(@cInclude("stdio.h"));
        \\export fn main(argc: c_int, argv: [*][*]u8) c_int {
        \\    _ = c.puts(c"Hello, world!");
        \\    return 0;
        \\}
    , "Hello, world!" ++ std.cstr.line_sep);

    cases.addCase(x: {
        var tc = cases.create("multiple files with private function",
            \\use @import("std").io;
            \\use @import("foo.zig");
            \\
            \\pub fn main() void {
            \\    privateFunction();
            \\    const stdout = &(FileOutStream.init(&(getStdOut() catch unreachable)).stream);
            \\    stdout.print("OK 2\n") catch unreachable;
            \\}
            \\
            \\fn privateFunction() void {
            \\    printText();
            \\}
        , "OK 1\nOK 2\n");

        tc.addSourceFile("foo.zig",
            \\use @import("std").io;
            \\
            \\// purposefully conflicting function with main.zig
            \\// but it's private so it should be OK
            \\fn privateFunction() void {
            \\    const stdout = &(FileOutStream.init(&(getStdOut() catch unreachable)).stream);
            \\    stdout.print("OK 1\n") catch unreachable;
            \\}
            \\
            \\pub fn printText() void {
            \\    privateFunction();
            \\}
        );

        break :x tc;
    });

    cases.addCase(x: {
        var tc = cases.create("import segregation",
            \\use @import("foo.zig");
            \\use @import("bar.zig");
            \\
            \\pub fn main() void {
            \\    foo_function();
            \\    bar_function();
            \\}
        , "OK\nOK\n");

        tc.addSourceFile("foo.zig",
            \\use @import("std").io;
            \\pub fn foo_function() void {
            \\    const stdout = &(FileOutStream.init(&(getStdOut() catch unreachable)).stream);
            \\    stdout.print("OK\n") catch unreachable;
            \\}
        );

        tc.addSourceFile("bar.zig",
            \\use @import("other.zig");
            \\use @import("std").io;
            \\
            \\pub fn bar_function() void {
            \\    if (foo_function()) {
            \\        const stdout = &(FileOutStream.init(&(getStdOut() catch unreachable)).stream);
            \\        stdout.print("OK\n") catch unreachable;
            \\    }
            \\}
        );

        tc.addSourceFile("other.zig",
            \\pub fn foo_function() bool {
            \\    // this one conflicts with the one from foo
            \\    return true;
            \\}
        );

        break :x tc;
    });

    cases.addCase(x: {
        var tc = cases.create("two files use import each other",
            \\use @import("a.zig");
            \\
            \\pub fn main() void {
            \\    ok();
            \\}
        , "OK\n");

        tc.addSourceFile("a.zig",
            \\use @import("b.zig");
            \\const io = @import("std").io;
            \\
            \\pub const a_text = "OK\n";
            \\
            \\pub fn ok() void {
            \\    const stdout = &(io.FileOutStream.init(&(io.getStdOut() catch unreachable)).stream);
            \\    stdout.print(b_text) catch unreachable;
            \\}
        );

        tc.addSourceFile("b.zig",
            \\use @import("a.zig");
            \\
            \\pub const b_text = a_text;
        );

        break :x tc;
    });

    cases.add("hello world without libc",
        \\const io = @import("std").io;
        \\
        \\pub fn main() void {
        \\    const stdout = &(io.FileOutStream.init(&(io.getStdOut() catch unreachable)).stream);
        \\    stdout.print("Hello, world!\n{d4} {x3} {c}\n", u32(12), u16(0x12), u8('a')) catch unreachable;
        \\}
    , "Hello, world!\n0012 012 a\n");

    cases.addC("number literals",
        \\const builtin = @import("builtin");
        \\const is_windows = builtin.os == builtin.Os.windows;
        \\const c = @cImport({
        \\    if (is_windows) {
        \\        // See https://github.com/ziglang/zig/issues/515
        \\        @cDefine("_NO_CRT_STDIO_INLINE", "1");
        \\        @cInclude("io.h");
        \\        @cInclude("fcntl.h");
        \\    }
        \\    @cInclude("stdio.h");
        \\});
        \\
        \\export fn main(argc: c_int, argv: [*][*]u8) c_int {
        \\    if (is_windows) {
        \\        // we want actual \n, not \r\n
        \\        _ = c._setmode(1, c._O_BINARY);
        \\    }
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
        \\    _ = c.printf(c"0.0: %.013a\n",
        \\         f64(0.0));
        \\    _ = c.printf(c"0e0: %.013a\n",
        \\         f64(0e0));
        \\    _ = c.printf(c"0.0e0: %.013a\n",
        \\         f64(0.0e0));
        \\    _ = c.printf(c"000000000000000000000000000000000000000000000000000000000.0e0: %.013a\n",
        \\         f64(000000000000000000000000000000000000000000000000000000000.0e0));
        \\    _ = c.printf(c"0.000000000000000000000000000000000000000000000000000000000e0: %.013a\n",
        \\         f64(0.000000000000000000000000000000000000000000000000000000000e0));
        \\    _ = c.printf(c"0.0e000000000000000000000000000000000000000000000000000000000: %.013a\n",
        \\         f64(0.0e000000000000000000000000000000000000000000000000000000000));
        \\    _ = c.printf(c"1.0: %.013a\n",
        \\         f64(1.0));
        \\    _ = c.printf(c"10.0: %.013a\n",
        \\         f64(10.0));
        \\    _ = c.printf(c"10.5: %.013a\n",
        \\         f64(10.5));
        \\    _ = c.printf(c"10.5e5: %.013a\n",
        \\         f64(10.5e5));
        \\    _ = c.printf(c"10.5e+5: %.013a\n",
        \\         f64(10.5e+5));
        \\    _ = c.printf(c"50.0e-2: %.013a\n",
        \\         f64(50.0e-2));
        \\    _ = c.printf(c"50e-2: %.013a\n",
        \\         f64(50e-2));
        \\
        \\    _ = c.printf(c"\n");
        \\
        \\    _ = c.printf(c"0x1.0: %.013a\n",
        \\         f64(0x1.0));
        \\    _ = c.printf(c"0x10.0: %.013a\n",
        \\         f64(0x10.0));
        \\    _ = c.printf(c"0x100.0: %.013a\n",
        \\         f64(0x100.0));
        \\    _ = c.printf(c"0x103.0: %.013a\n",
        \\         f64(0x103.0));
        \\    _ = c.printf(c"0x103.7: %.013a\n",
        \\         f64(0x103.7));
        \\    _ = c.printf(c"0x103.70: %.013a\n",
        \\         f64(0x103.70));
        \\    _ = c.printf(c"0x103.70p4: %.013a\n",
        \\         f64(0x103.70p4));
        \\    _ = c.printf(c"0x103.70p5: %.013a\n",
        \\         f64(0x103.70p5));
        \\    _ = c.printf(c"0x103.70p+5: %.013a\n",
        \\         f64(0x103.70p+5));
        \\    _ = c.printf(c"0x103.70p-5: %.013a\n",
        \\         f64(0x103.70p-5));
        \\
        \\    _ = c.printf(c"\n");
        \\
        \\    _ = c.printf(c"0b10100.00010e0: %.013a\n",
        \\         f64(0b10100.00010e0));
        \\    _ = c.printf(c"0o10700.00010e0: %.013a\n",
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
        \\0.0: 0x0.0000000000000p+0
        \\0e0: 0x0.0000000000000p+0
        \\0.0e0: 0x0.0000000000000p+0
        \\000000000000000000000000000000000000000000000000000000000.0e0: 0x0.0000000000000p+0
        \\0.000000000000000000000000000000000000000000000000000000000e0: 0x0.0000000000000p+0
        \\0.0e000000000000000000000000000000000000000000000000000000000: 0x0.0000000000000p+0
        \\1.0: 0x1.0000000000000p+0
        \\10.0: 0x1.4000000000000p+3
        \\10.5: 0x1.5000000000000p+3
        \\10.5e5: 0x1.0059000000000p+20
        \\10.5e+5: 0x1.0059000000000p+20
        \\50.0e-2: 0x1.0000000000000p-1
        \\50e-2: 0x1.0000000000000p-1
        \\
        \\0x1.0: 0x1.0000000000000p+0
        \\0x10.0: 0x1.0000000000000p+4
        \\0x100.0: 0x1.0000000000000p+8
        \\0x103.0: 0x1.0300000000000p+8
        \\0x103.7: 0x1.0370000000000p+8
        \\0x103.70: 0x1.0370000000000p+8
        \\0x103.70p4: 0x1.0370000000000p+12
        \\0x103.70p5: 0x1.0370000000000p+13
        \\0x103.70p+5: 0x1.0370000000000p+13
        \\0x103.70p-5: 0x1.0370000000000p+3
        \\
        \\0b10100.00010e0: 0x1.4100000000000p+4
        \\0o10700.00010e0: 0x1.1c00010000000p+12
        \\
    );

    cases.add("order-independent declarations",
        \\const io = @import("std").io;
        \\const z = io.stdin_fileno;
        \\const x : @typeOf(y) = 1234;
        \\const y : u16 = 5678;
        \\pub fn main() void {
        \\    var x_local : i32 = print_ok(x);
        \\}
        \\fn print_ok(val: @typeOf(x)) @typeOf(foo) {
        \\    const stdout = &(io.FileOutStream.init(&(io.getStdOut() catch unreachable)).stream);
        \\    stdout.print("OK\n") catch unreachable;
        \\    return 0;
        \\}
        \\const foo : i32 = 0;
    , "OK\n");

    cases.addC("expose function pointer to C land",
        \\const c = @cImport(@cInclude("stdlib.h"));
        \\
        \\export fn compare_fn(a: ?*const c_void, b: ?*const c_void) c_int {
        \\    const a_int = @ptrCast(*const i32, @alignCast(@alignOf(i32), a));
        \\    const b_int = @ptrCast(*const i32, @alignCast(@alignOf(i32), b));
        \\    if (a_int.* < b_int.*) {
        \\        return -1;
        \\    } else if (a_int.* > b_int.*) {
        \\        return 1;
        \\    } else {
        \\        return 0;
        \\    }
        \\}
        \\
        \\export fn main() c_int {
        \\    var array = []u32{ 1, 7, 3, 2, 0, 9, 4, 8, 6, 5 };
        \\
        \\    c.qsort(@ptrCast(?*c_void, array[0..].ptr), @intCast(c_ulong, array.len), @sizeOf(i32), compare_fn);
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
        \\const builtin = @import("builtin");
        \\const is_windows = builtin.os == builtin.Os.windows;
        \\const c = @cImport({
        \\    if (is_windows) {
        \\        // See https://github.com/ziglang/zig/issues/515
        \\        @cDefine("_NO_CRT_STDIO_INLINE", "1");
        \\        @cInclude("io.h");
        \\        @cInclude("fcntl.h");
        \\    }
        \\    @cInclude("stdio.h");
        \\});
        \\
        \\export fn main(argc: c_int, argv: [*][*]u8) c_int {
        \\    if (is_windows) {
        \\        // we want actual \n, not \r\n
        \\        _ = c._setmode(1, c._O_BINARY);
        \\    }
        \\    const small: f32 = 3.25;
        \\    const x: f64 = small;
        \\    const y = @floatToInt(i32, x);
        \\    const z = @intToFloat(f64, y);
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
        \\    fn method(a: *const Foo) bool { return true; }
        \\};
        \\
        \\const Bar = struct {
        \\    field2: i32,
        \\
        \\    fn method(b: *const Bar) bool { return true; }
        \\};
        \\
        \\pub fn main() void {
        \\    const bar = Bar {.field2 = 13,};
        \\    const foo = Foo {.field1 = bar,};
        \\    const stdout = &(io.FileOutStream.init(&(io.getStdOut() catch unreachable)).stream);
        \\    if (!foo.method()) {
        \\        stdout.print("BAD\n") catch unreachable;
        \\    }
        \\    if (!bar.method()) {
        \\        stdout.print("BAD\n") catch unreachable;
        \\    }
        \\    stdout.print("OK\n") catch unreachable;
        \\}
    , "OK\n");

    cases.add("defer with only fallthrough",
        \\const io = @import("std").io;
        \\pub fn main() void {
        \\    const stdout = &(io.FileOutStream.init(&(io.getStdOut() catch unreachable)).stream);
        \\    stdout.print("before\n") catch unreachable;
        \\    defer stdout.print("defer1\n") catch unreachable;
        \\    defer stdout.print("defer2\n") catch unreachable;
        \\    defer stdout.print("defer3\n") catch unreachable;
        \\    stdout.print("after\n") catch unreachable;
        \\}
    , "before\nafter\ndefer3\ndefer2\ndefer1\n");

    cases.add("defer with return",
        \\const io = @import("std").io;
        \\const os = @import("std").os;
        \\pub fn main() void {
        \\    const stdout = &(io.FileOutStream.init(&(io.getStdOut() catch unreachable)).stream);
        \\    stdout.print("before\n") catch unreachable;
        \\    defer stdout.print("defer1\n") catch unreachable;
        \\    defer stdout.print("defer2\n") catch unreachable;
        \\    var args_it = @import("std").os.args();
        \\    if (args_it.skip() and !args_it.skip()) return;
        \\    defer stdout.print("defer3\n") catch unreachable;
        \\    stdout.print("after\n") catch unreachable;
        \\}
    , "before\ndefer2\ndefer1\n");

    cases.add("errdefer and it fails",
        \\const io = @import("std").io;
        \\pub fn main() void {
        \\    do_test() catch return;
        \\}
        \\fn do_test() !void {
        \\    const stdout = &(io.FileOutStream.init(&(io.getStdOut() catch unreachable)).stream);
        \\    stdout.print("before\n") catch unreachable;
        \\    defer stdout.print("defer1\n") catch unreachable;
        \\    errdefer stdout.print("deferErr\n") catch unreachable;
        \\    try its_gonna_fail();
        \\    defer stdout.print("defer3\n") catch unreachable;
        \\    stdout.print("after\n") catch unreachable;
        \\}
        \\fn its_gonna_fail() !void {
        \\    return error.IToldYouItWouldFail;
        \\}
    , "before\ndeferErr\ndefer1\n");

    cases.add("errdefer and it passes",
        \\const io = @import("std").io;
        \\pub fn main() void {
        \\    do_test() catch return;
        \\}
        \\fn do_test() !void {
        \\    const stdout = &(io.FileOutStream.init(&(io.getStdOut() catch unreachable)).stream);
        \\    stdout.print("before\n") catch unreachable;
        \\    defer stdout.print("defer1\n") catch unreachable;
        \\    errdefer stdout.print("deferErr\n") catch unreachable;
        \\    try its_gonna_pass();
        \\    defer stdout.print("defer3\n") catch unreachable;
        \\    stdout.print("after\n") catch unreachable;
        \\}
        \\fn its_gonna_pass() error!void { }
    , "before\nafter\ndefer3\ndefer1\n");

    cases.addCase(x: {
        var tc = cases.create("@embedFile",
            \\const foo_txt = @embedFile("foo.txt");
            \\const io = @import("std").io;
            \\
            \\pub fn main() void {
            \\    const stdout = &(io.FileOutStream.init(&(io.getStdOut() catch unreachable)).stream);
            \\    stdout.print(foo_txt) catch unreachable;
            \\}
        , "1234\nabcd\n");

        tc.addSourceFile("foo.txt", "1234\nabcd\n");

        break :x tc;
    });

    cases.addCase(x: {
        var tc = cases.create("parsing args",
            \\const std = @import("std");
            \\const io = std.io;
            \\const os = std.os;
            \\const allocator = std.debug.global_allocator;
            \\
            \\pub fn main() !void {
            \\    var args_it = os.args();
            \\    var stdout_file = try io.getStdOut();
            \\    var stdout_adapter = io.FileOutStream.init(&stdout_file);
            \\    const stdout = &stdout_adapter.stream;
            \\    var index: usize = 0;
            \\    _ = args_it.skip();
            \\    while (args_it.next(allocator)) |arg_or_err| : (index += 1) {
            \\        const arg = try arg_or_err;
            \\        try stdout.print("{}: {}\n", index, arg);
            \\    }
            \\}
        ,
            \\0: first arg
            \\1: 'a' 'b' \
            \\2: bare
            \\3: ba""re
            \\4: "
            \\5: last arg
            \\
        );

        tc.setCommandLineArgs([][]const u8{
            "first arg",
            "'a' 'b' \\",
            "bare",
            "ba\"\"re",
            "\"",
            "last arg",
        });

        break :x tc;
    });

    cases.addCase(x: {
        var tc = cases.create("parsing args new API",
            \\const std = @import("std");
            \\const io = std.io;
            \\const os = std.os;
            \\const allocator = std.debug.global_allocator;
            \\
            \\pub fn main() !void {
            \\    var args_it = os.args();
            \\    var stdout_file = try io.getStdOut();
            \\    var stdout_adapter = io.FileOutStream.init(&stdout_file);
            \\    const stdout = &stdout_adapter.stream;
            \\    var index: usize = 0;
            \\    _ = args_it.skip();
            \\    while (args_it.next(allocator)) |arg_or_err| : (index += 1) {
            \\        const arg = try arg_or_err;
            \\        try stdout.print("{}: {}\n", index, arg);
            \\    }
            \\}
        ,
            \\0: first arg
            \\1: 'a' 'b' \
            \\2: bare
            \\3: ba""re
            \\4: "
            \\5: last arg
            \\
        );

        tc.setCommandLineArgs([][]const u8{
            "first arg",
            "'a' 'b' \\",
            "bare",
            "ba\"\"re",
            "\"",
            "last arg",
        });

        break :x tc;
    });
}

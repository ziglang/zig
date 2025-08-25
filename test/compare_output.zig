const std = @import("std");
const os = std.os;
const tests = @import("tests.zig");

pub fn addCases(cases: *tests.CompareOutputContext) void {
    cases.addC("hello world with libc",
        \\const c = @cImport({
        \\    // See https://github.com/ziglang/zig/issues/515
        \\    @cDefine("_NO_CRT_STDIO_INLINE", "1");
        \\    @cInclude("stdio.h");
        \\});
        \\pub export fn main(argc: c_int, argv: [*][*]u8) c_int {
        \\    _ = argc;
        \\    _ = argv;
        \\    _ = c.puts("Hello, world!");
        \\    return 0;
        \\}
    , "Hello, world!" ++ if (@import("builtin").os.tag == .windows) "\r\n" else "\n");

    cases.addC("number literals",
        \\const std = @import("std");
        \\const builtin = @import("builtin");
        \\const is_windows = builtin.os.tag == .windows;
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
        \\pub export fn main(argc: c_int, argv: [*][*]u8) c_int {
        \\    _ = argc;
        \\    _ = argv;
        \\    if (is_windows) {
        \\        // we want actual \n, not \r\n
        \\        _ = c._setmode(1, c._O_BINARY);
        \\    }
        \\    _ = c.printf("0: %llu\n",
        \\             @as(u64, 0));
        \\    _ = c.printf("320402575052271: %llu\n",
        \\         @as(u64, 320402575052271));
        \\    _ = c.printf("0x01236789abcdef: %llu\n",
        \\         @as(u64, 0x01236789abcdef));
        \\    _ = c.printf("0xffffffffffffffff: %llu\n",
        \\         @as(u64, 0xffffffffffffffff));
        \\    _ = c.printf("0x000000ffffffffffffffff: %llu\n",
        \\         @as(u64, 0x000000ffffffffffffffff));
        \\    _ = c.printf("0o1777777777777777777777: %llu\n",
        \\         @as(u64, 0o1777777777777777777777));
        \\    _ = c.printf("0o0000001777777777777777777777: %llu\n",
        \\         @as(u64, 0o0000001777777777777777777777));
        \\    _ = c.printf("0b1111111111111111111111111111111111111111111111111111111111111111: %llu\n",
        \\         @as(u64, 0b1111111111111111111111111111111111111111111111111111111111111111));
        \\    _ = c.printf("0b0000001111111111111111111111111111111111111111111111111111111111111111: %llu\n",
        \\         @as(u64, 0b0000001111111111111111111111111111111111111111111111111111111111111111));
        \\
        \\    _ = c.printf("\n");
        \\
        \\    _ = c.printf("0.0: %.013a\n",
        \\         @as(f64, 0.0));
        \\    _ = c.printf("0e0: %.013a\n",
        \\         @as(f64, 0e0));
        \\    _ = c.printf("0.0e0: %.013a\n",
        \\         @as(f64, 0.0e0));
        \\    _ = c.printf("000000000000000000000000000000000000000000000000000000000.0e0: %.013a\n",
        \\         @as(f64, 0.0e0));
        \\    _ = c.printf("0.000000000000000000000000000000000000000000000000000000000e0: %.013a\n",
        \\         @as(f64, 0.000000000000000000000000000000000000000000000000000000000e0));
        \\    _ = c.printf("0.0e000000000000000000000000000000000000000000000000000000000: %.013a\n",
        \\         @as(f64, 0.0e000000000000000000000000000000000000000000000000000000000));
        \\    _ = c.printf("1.0: %.013a\n",
        \\         @as(f64, 1.0));
        \\    _ = c.printf("10.0: %.013a\n",
        \\         @as(f64, 10.0));
        \\    _ = c.printf("10.5: %.013a\n",
        \\         @as(f64, 10.5));
        \\    _ = c.printf("10.5e5: %.013a\n",
        \\         @as(f64, 10.5e5));
        \\    _ = c.printf("10.5e+5: %.013a\n",
        \\         @as(f64, 10.5e+5));
        \\    _ = c.printf("50.0e-2: %.013a\n",
        \\         @as(f64, 50.0e-2));
        \\    _ = c.printf("50e-2: %.013a\n",
        \\         @as(f64, 50e-2));
        \\
        \\    _ = c.printf("\n");
        \\
        \\    _ = c.printf("0x1.0: %.013a\n",
        \\         @as(f64, 0x1.0));
        \\    _ = c.printf("0x10.0: %.013a\n",
        \\         @as(f64, 0x10.0));
        \\    _ = c.printf("0x100.0: %.013a\n",
        \\         @as(f64, 0x100.0));
        \\    _ = c.printf("0x103.0: %.013a\n",
        \\         @as(f64, 0x103.0));
        \\    _ = c.printf("0x103.7: %.013a\n",
        \\         @as(f64, 0x103.7));
        \\    _ = c.printf("0x103.70: %.013a\n",
        \\         @as(f64, 0x103.70));
        \\    _ = c.printf("0x103.70p4: %.013a\n",
        \\         @as(f64, 0x103.70p4));
        \\    _ = c.printf("0x103.70p5: %.013a\n",
        \\         @as(f64, 0x103.70p5));
        \\    _ = c.printf("0x103.70p+5: %.013a\n",
        \\         @as(f64, 0x103.70p+5));
        \\    _ = c.printf("0x103.70p-5: %.013a\n",
        \\         @as(f64, 0x103.70p-5));
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
    );

    cases.addC("expose function pointer to C land",
        \\const c = @cImport(@cInclude("stdlib.h"));
        \\
        \\export fn compare_fn(a: ?*const anyopaque, b: ?*const anyopaque) c_int {
        \\    const a_int: *const i32 = @ptrCast(@alignCast(a));
        \\    const b_int: *const i32 = @ptrCast(@alignCast(b));
        \\    if (a_int.* < b_int.*) {
        \\        return -1;
        \\    } else if (a_int.* > b_int.*) {
        \\        return 1;
        \\    } else {
        \\        return 0;
        \\    }
        \\}
        \\
        \\pub export fn main() c_int {
        \\    var array = [_]u32{ 1, 7, 3, 2, 0, 9, 4, 8, 6, 5 };
        \\
        \\    c.qsort(@ptrCast(&array), @intCast(array.len), @sizeOf(i32), compare_fn);
        \\
        \\    for (array, 0..) |item, i| {
        \\        if (item != i) {
        \\            c.abort();
        \\        }
        \\    }
        \\
        \\    return 0;
        \\}
    , "");

    cases.addC("casting between float and integer types",
        \\const std = @import("std");
        \\const builtin = @import("builtin");
        \\const is_windows = builtin.os.tag == .windows;
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
        \\pub export fn main(argc: c_int, argv: [*][*]u8) c_int {
        \\    _ = argc;
        \\    _ = argv;
        \\    if (is_windows) {
        \\        // we want actual \n, not \r\n
        \\        _ = c._setmode(1, c._O_BINARY);
        \\    }
        \\    const small: f32 = 3.25;
        \\    const x: f64 = small;
        \\    const y: i32 = @intFromFloat(x);
        \\    const z: f64 = @floatFromInt(y);
        \\    _ = c.printf("%.2f\n%d\n%.2f\n%.2f\n", x, y, z, @as(f64, -0.4));
        \\    return 0;
        \\}
    , "3.25\n3\n3.00\n-0.40\n");

    cases.add("valid carriage return example", "const std = @import(\"std\");\r\n" ++ // Testing CRLF line endings are valid
        "\r\n" ++
        "pub \r fn main() void {\r\n" ++ // Testing isolated carriage return as whitespace is valid
        "    var file_writer = std.fs.File.stdout().writerStreaming(&.{});\r\n" ++
        "    const stdout = &file_writer.interface;\r\n" ++
        "    stdout.print(\\\\A Multiline\r\n" ++ // testing CRLF at end of multiline string line is valid and normalises to \n in the output
        "                 \\\\String\r\n" ++
        "                 , .{}) catch unreachable;\r\n" ++
        "}\r\n", "A Multiline\nString");
}

const tests = @import("tests.zig");

pub fn addCases(cases: *tests.CompareOutputContext) void {
    cases.addRuntimeSafety("@intToEnum - no matching tag value",
        \\pub fn panic(message: []const u8, stack_trace: ?*@import("builtin").StackTrace) noreturn {
        \\    @import("std").os.exit(126);
        \\}
        \\const Foo = enum {
        \\    A,
        \\    B,
        \\    C,
        \\};
        \\pub fn main() void {
        \\    baz(bar(3));
        \\}
        \\fn bar(a: u2) Foo {
        \\    return @intToEnum(Foo, a);
        \\}
        \\fn baz(a: Foo) void {}
    );

    cases.addRuntimeSafety("@floatToInt cannot fit - negative to unsigned",
        \\pub fn panic(message: []const u8, stack_trace: ?*@import("builtin").StackTrace) noreturn {
        \\    @import("std").os.exit(126);
        \\}
        \\pub fn main() void {
        \\    baz(bar(-1.1));
        \\}
        \\fn bar(a: f32) u8 {
        \\    return @floatToInt(u8, a);
        \\}
        \\fn baz(a: u8) void { }
    );

    cases.addRuntimeSafety("@floatToInt cannot fit - negative out of range",
        \\pub fn panic(message: []const u8, stack_trace: ?*@import("builtin").StackTrace) noreturn {
        \\    @import("std").os.exit(126);
        \\}
        \\pub fn main() void {
        \\    baz(bar(-129.1));
        \\}
        \\fn bar(a: f32) i8 {
        \\    return @floatToInt(i8, a);
        \\}
        \\fn baz(a: i8) void { }
    );

    cases.addRuntimeSafety("@floatToInt cannot fit - positive out of range",
        \\pub fn panic(message: []const u8, stack_trace: ?*@import("builtin").StackTrace) noreturn {
        \\    @import("std").os.exit(126);
        \\}
        \\pub fn main() void {
        \\    baz(bar(256.2));
        \\}
        \\fn bar(a: f32) u8 {
        \\    return @floatToInt(u8, a);
        \\}
        \\fn baz(a: u8) void { }
    );

    cases.addRuntimeSafety("calling panic",
        \\pub fn panic(message: []const u8, stack_trace: ?*@import("builtin").StackTrace) noreturn {
        \\    @import("std").os.exit(126);
        \\}
        \\pub fn main() void {
        \\    @panic("oh no");
        \\}
    );

    cases.addRuntimeSafety("out of bounds slice access",
        \\pub fn panic(message: []const u8, stack_trace: ?*@import("builtin").StackTrace) noreturn {
        \\    @import("std").os.exit(126);
        \\}
        \\pub fn main() void {
        \\    const a = []i32{1, 2, 3, 4};
        \\    baz(bar(a));
        \\}
        \\fn bar(a: []const i32) i32 {
        \\    return a[4];
        \\}
        \\fn baz(a: i32) void { }
    );

    cases.addRuntimeSafety("integer addition overflow",
        \\pub fn panic(message: []const u8, stack_trace: ?*@import("builtin").StackTrace) noreturn {
        \\    @import("std").os.exit(126);
        \\}
        \\pub fn main() !void {
        \\    const x = add(65530, 10);
        \\    if (x == 0) return error.Whatever;
        \\}
        \\fn add(a: u16, b: u16) u16 {
        \\    return a + b;
        \\}
    );

    cases.addRuntimeSafety("integer subtraction overflow",
        \\pub fn panic(message: []const u8, stack_trace: ?*@import("builtin").StackTrace) noreturn {
        \\    @import("std").os.exit(126);
        \\}
        \\pub fn main() !void {
        \\    const x = sub(10, 20);
        \\    if (x == 0) return error.Whatever;
        \\}
        \\fn sub(a: u16, b: u16) u16 {
        \\    return a - b;
        \\}
    );

    cases.addRuntimeSafety("integer multiplication overflow",
        \\pub fn panic(message: []const u8, stack_trace: ?*@import("builtin").StackTrace) noreturn {
        \\    @import("std").os.exit(126);
        \\}
        \\pub fn main() !void {
        \\    const x = mul(300, 6000);
        \\    if (x == 0) return error.Whatever;
        \\}
        \\fn mul(a: u16, b: u16) u16 {
        \\    return a * b;
        \\}
    );

    cases.addRuntimeSafety("integer negation overflow",
        \\pub fn panic(message: []const u8, stack_trace: ?*@import("builtin").StackTrace) noreturn {
        \\    @import("std").os.exit(126);
        \\}
        \\pub fn main() !void {
        \\    const x = neg(-32768);
        \\    if (x == 32767) return error.Whatever;
        \\}
        \\fn neg(a: i16) i16 {
        \\    return -a;
        \\}
    );

    cases.addRuntimeSafety("signed integer division overflow",
        \\pub fn panic(message: []const u8, stack_trace: ?*@import("builtin").StackTrace) noreturn {
        \\    @import("std").os.exit(126);
        \\}
        \\pub fn main() !void {
        \\    const x = div(-32768, -1);
        \\    if (x == 32767) return error.Whatever;
        \\}
        \\fn div(a: i16, b: i16) i16 {
        \\    return @divTrunc(a, b);
        \\}
    );

    cases.addRuntimeSafety("signed shift left overflow",
        \\pub fn panic(message: []const u8, stack_trace: ?*@import("builtin").StackTrace) noreturn {
        \\    @import("std").os.exit(126);
        \\}
        \\pub fn main() !void {
        \\    const x = shl(-16385, 1);
        \\    if (x == 0) return error.Whatever;
        \\}
        \\fn shl(a: i16, b: u4) i16 {
        \\    return @shlExact(a, b);
        \\}
    );

    cases.addRuntimeSafety("unsigned shift left overflow",
        \\pub fn panic(message: []const u8, stack_trace: ?*@import("builtin").StackTrace) noreturn {
        \\    @import("std").os.exit(126);
        \\}
        \\pub fn main() !void {
        \\    const x = shl(0b0010111111111111, 3);
        \\    if (x == 0) return error.Whatever;
        \\}
        \\fn shl(a: u16, b: u4) u16 {
        \\    return @shlExact(a, b);
        \\}
    );

    cases.addRuntimeSafety("signed shift right overflow",
        \\pub fn panic(message: []const u8, stack_trace: ?*@import("builtin").StackTrace) noreturn {
        \\    @import("std").os.exit(126);
        \\}
        \\pub fn main() !void {
        \\    const x = shr(-16385, 1);
        \\    if (x == 0) return error.Whatever;
        \\}
        \\fn shr(a: i16, b: u4) i16 {
        \\    return @shrExact(a, b);
        \\}
    );

    cases.addRuntimeSafety("unsigned shift right overflow",
        \\pub fn panic(message: []const u8, stack_trace: ?*@import("builtin").StackTrace) noreturn {
        \\    @import("std").os.exit(126);
        \\}
        \\pub fn main() !void {
        \\    const x = shr(0b0010111111111111, 3);
        \\    if (x == 0) return error.Whatever;
        \\}
        \\fn shr(a: u16, b: u4) u16 {
        \\    return @shrExact(a, b);
        \\}
    );

    cases.addRuntimeSafety("integer division by zero",
        \\pub fn panic(message: []const u8, stack_trace: ?*@import("builtin").StackTrace) noreturn {
        \\    @import("std").os.exit(126);
        \\}
        \\pub fn main() void {
        \\    const x = div0(999, 0);
        \\}
        \\fn div0(a: i32, b: i32) i32 {
        \\    return @divTrunc(a, b);
        \\}
    );

    cases.addRuntimeSafety("exact division failure",
        \\pub fn panic(message: []const u8, stack_trace: ?*@import("builtin").StackTrace) noreturn {
        \\    @import("std").os.exit(126);
        \\}
        \\pub fn main() !void {
        \\    const x = divExact(10, 3);
        \\    if (x == 0) return error.Whatever;
        \\}
        \\fn divExact(a: i32, b: i32) i32 {
        \\    return @divExact(a, b);
        \\}
    );

    cases.addRuntimeSafety("cast []u8 to bigger slice of wrong size",
        \\pub fn panic(message: []const u8, stack_trace: ?*@import("builtin").StackTrace) noreturn {
        \\    @import("std").os.exit(126);
        \\}
        \\pub fn main() !void {
        \\    const x = widenSlice([]u8{1, 2, 3, 4, 5});
        \\    if (x.len == 0) return error.Whatever;
        \\}
        \\fn widenSlice(slice: []align(1) const u8) []align(1) const i32 {
        \\    return @bytesToSlice(i32, slice);
        \\}
    );

    cases.addRuntimeSafety("value does not fit in shortening cast",
        \\pub fn panic(message: []const u8, stack_trace: ?*@import("builtin").StackTrace) noreturn {
        \\    @import("std").os.exit(126);
        \\}
        \\pub fn main() !void {
        \\    const x = shorten_cast(200);
        \\    if (x == 0) return error.Whatever;
        \\}
        \\fn shorten_cast(x: i32) i8 {
        \\    return @intCast(i8, x);
        \\}
    );

    cases.addRuntimeSafety("signed integer not fitting in cast to unsigned integer",
        \\pub fn panic(message: []const u8, stack_trace: ?*@import("builtin").StackTrace) noreturn {
        \\    @import("std").os.exit(126);
        \\}
        \\pub fn main() !void {
        \\    const x = unsigned_cast(-10);
        \\    if (x == 0) return error.Whatever;
        \\}
        \\fn unsigned_cast(x: i32) u32 {
        \\    return @intCast(u32, x);
        \\}
    );

    cases.addRuntimeSafety("unwrap error",
        \\pub fn panic(message: []const u8, stack_trace: ?*@import("builtin").StackTrace) noreturn {
        \\    if (@import("std").mem.eql(u8, message, "attempt to unwrap error: Whatever")) {
        \\        @import("std").os.exit(126); // good
        \\    }
        \\    @import("std").os.exit(0); // test failed
        \\}
        \\pub fn main() void {
        \\    bar() catch unreachable;
        \\}
        \\fn bar() !void {
        \\    return error.Whatever;
        \\}
    );

    cases.addRuntimeSafety("cast integer to global error and no code matches",
        \\pub fn panic(message: []const u8, stack_trace: ?*@import("builtin").StackTrace) noreturn {
        \\    @import("std").os.exit(126);
        \\}
        \\pub fn main() void {
        \\    _ = bar(9999);
        \\}
        \\fn bar(x: u16) error {
        \\    return @intToError(x);
        \\}
    );

    cases.addRuntimeSafety("@errSetCast error not present in destination",
        \\pub fn panic(message: []const u8, stack_trace: ?*@import("builtin").StackTrace) noreturn {
        \\    @import("std").os.exit(126);
        \\}
        \\const Set1 = error{A, B};
        \\const Set2 = error{A, C};
        \\pub fn main() void {
        \\    _ = foo(Set1.B);
        \\}
        \\fn foo(set1: Set1) Set2 {
        \\    return @errSetCast(Set2, set1);
        \\}
    );

    cases.addRuntimeSafety("@alignCast misaligned",
        \\pub fn panic(message: []const u8, stack_trace: ?*@import("builtin").StackTrace) noreturn {
        \\    @import("std").os.exit(126);
        \\}
        \\pub fn main() !void {
        \\    var array align(4) = []u32{0x11111111, 0x11111111};
        \\    const bytes = @sliceToBytes(array[0..]);
        \\    if (foo(bytes) != 0x11111111) return error.Wrong;
        \\}
        \\fn foo(bytes: []u8) u32 {
        \\    const slice4 = bytes[1..5];
        \\    const int_slice = @bytesToSlice(u32, @alignCast(4, slice4));
        \\    return int_slice[0];
        \\}
    );

    cases.addRuntimeSafety("bad union field access",
        \\pub fn panic(message: []const u8, stack_trace: ?*@import("builtin").StackTrace) noreturn {
        \\    @import("std").os.exit(126);
        \\}
        \\
        \\const Foo = union {
        \\    float: f32,
        \\    int: u32,
        \\};
        \\
        \\pub fn main() void {
        \\    var f = Foo { .int = 42 };
        \\    bar(&f);
        \\}
        \\
        \\fn bar(f: *Foo) void {
        \\    f.float = 12.34;
        \\}
    );

    // This case makes sure that the code compiles and runs. There is not actually a special
    // runtime safety check having to do specifically with error return traces across suspend points.
    cases.addRuntimeSafety("error return trace across suspend points",
        \\const std = @import("std");
        \\
        \\pub fn panic(message: []const u8, stack_trace: ?*@import("builtin").StackTrace) noreturn {
        \\    std.os.exit(126);
        \\}
        \\
        \\pub fn main() void {
        \\    const p = nonFailing();
        \\    resume p;
        \\    const p2 = async<std.debug.global_allocator> printTrace(p) catch unreachable;
        \\    cancel p2;
        \\}
        \\
        \\fn nonFailing() promise->error!void {
        \\    return async<std.debug.global_allocator> failing() catch unreachable;
        \\}
        \\
        \\async fn failing() error!void {
        \\    suspend;
        \\    return error.Fail;
        \\}
        \\
        \\async fn printTrace(p: promise->error!void) void {
        \\    (await p) catch unreachable;
        \\}
    );
}

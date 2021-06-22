const tests = @import("tests.zig");

pub fn addCases(cases: *tests.CompareOutputContext) void {
    {
        const check_panic_msg =
            \\pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace) noreturn {
            \\    _ = stack_trace;
            \\    if (std.mem.eql(u8, message, "reached unreachable code")) {
            \\        std.process.exit(126); // good
            \\    }
            \\    std.process.exit(0); // test failed
            \\}
        ;

        cases.addRuntimeSafety("switch on corrupted enum value",
            \\const std = @import("std");
        ++ check_panic_msg ++
            \\const E = enum(u32) {
            \\    X = 1,
            \\};
            \\pub fn main() void {
            \\    var e: E = undefined;
            \\    @memset(@ptrCast([*]u8, &e), 0x55, @sizeOf(E));
            \\    switch (e) {
            \\        .X => @breakpoint(),
            \\    }
            \\}
        );

        cases.addRuntimeSafety("switch on corrupted union value",
            \\const std = @import("std");
        ++ check_panic_msg ++
            \\const U = union(enum(u32)) {
            \\    X: u8,
            \\};
            \\pub fn main() void {
            \\    var u: U = undefined;
            \\    @memset(@ptrCast([*]u8, &u), 0x55, @sizeOf(U));
            \\    switch (u) {
            \\        .X => @breakpoint(),
            \\    }
            \\}
        );
    }

    {
        const check_panic_msg =
            \\pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace) noreturn {
            \\    _ = stack_trace;
            \\    if (std.mem.eql(u8, message, "invalid enum value")) {
            \\        std.process.exit(126); // good
            \\    }
            \\    std.process.exit(0); // test failed
            \\}
        ;

        cases.addRuntimeSafety("@tagName on corrupted enum value",
            \\const std = @import("std");
        ++ check_panic_msg ++
            \\const E = enum(u32) {
            \\    X = 1,
            \\};
            \\pub fn main() void {
            \\    var e: E = undefined;
            \\    @memset(@ptrCast([*]u8, &e), 0x55, @sizeOf(E));
            \\    var n = @tagName(e);
            \\    _ = n;
            \\}
        );

        cases.addRuntimeSafety("@tagName on corrupted union value",
            \\const std = @import("std");
        ++ check_panic_msg ++
            \\const U = union(enum(u32)) {
            \\    X: u8,
            \\};
            \\pub fn main() void {
            \\    var u: U = undefined;
            \\    @memset(@ptrCast([*]u8, &u), 0x55, @sizeOf(U));
            \\    var t: @typeInfo(U).Union.tag_type.? = u;
            \\    var n = @tagName(t);
            \\    _ = n;
            \\}
        );
    }

    {
        const check_panic_msg =
            \\pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace) noreturn {
            \\    _ = stack_trace;
            \\    if (std.mem.eql(u8, message, "index out of bounds")) {
            \\        std.process.exit(126); // good
            \\    }
            \\    std.process.exit(0); // test failed
            \\}
        ;

        cases.addRuntimeSafety("slicing operator with sentinel",
            \\const std = @import("std");
        ++ check_panic_msg ++
            \\pub fn main() void {
            \\    var buf = [4]u8{'a','b','c',0};
            \\    const slice = buf[0..4 :0];
            \\    _ = slice;
            \\}
        );
        cases.addRuntimeSafety("slicing operator with sentinel",
            \\const std = @import("std");
        ++ check_panic_msg ++
            \\pub fn main() void {
            \\    var buf = [4]u8{'a','b','c',0};
            \\    const slice = buf[0..:0];
            \\    _ = slice;
            \\}
        );
        cases.addRuntimeSafety("slicing operator with sentinel",
            \\const std = @import("std");
        ++ check_panic_msg ++
            \\pub fn main() void {
            \\    var buf_zero = [0]u8{};
            \\    const slice = buf_zero[0..0 :0];
            \\    _ = slice;
            \\}
        );
        cases.addRuntimeSafety("slicing operator with sentinel",
            \\const std = @import("std");
        ++ check_panic_msg ++
            \\pub fn main() void {
            \\    var buf_zero = [0]u8{};
            \\    const slice = buf_zero[0..:0];
            \\    _ = slice;
            \\}
        );
        cases.addRuntimeSafety("slicing operator with sentinel",
            \\const std = @import("std");
        ++ check_panic_msg ++
            \\pub fn main() void {
            \\    var buf_sentinel = [2:0]u8{'a','b'};
            \\    @ptrCast(*[3]u8, &buf_sentinel)[2] = 0;
            \\    const slice = buf_sentinel[0..3 :0];
            \\    _ = slice;
            \\}
        );
        cases.addRuntimeSafety("slicing operator with sentinel",
            \\const std = @import("std");
        ++ check_panic_msg ++
            \\pub fn main() void {
            \\    var buf_slice: []const u8 = &[3]u8{ 'a', 'b', 0 };
            \\    const slice = buf_slice[0..3 :0];
            \\    _ = slice;
            \\}
        );
        cases.addRuntimeSafety("slicing operator with sentinel",
            \\const std = @import("std");
        ++ check_panic_msg ++
            \\pub fn main() void {
            \\    var buf_slice: []const u8 = &[3]u8{ 'a', 'b', 0 };
            \\    const slice = buf_slice[0.. :0];
            \\    _ = slice;
            \\}
        );
    }

    cases.addRuntimeSafety("truncating vector cast",
        \\const std = @import("std");
        \\const V = @import("std").meta.Vector;
        \\pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace) noreturn {
        \\    _ = stack_trace;
        \\    if (std.mem.eql(u8, message, "integer cast truncated bits")) {
        \\        std.process.exit(126); // good
        \\    }
        \\    std.process.exit(0); // test failed
        \\}
        \\pub fn main() void {
        \\    var x = @splat(4, @as(u32, 0xdeadbeef));
        \\    var y = @intCast(V(4, u16), x);
        \\    _ = y;
        \\}
    );

    cases.addRuntimeSafety("unsigned-signed vector cast",
        \\const std = @import("std");
        \\const V = @import("std").meta.Vector;
        \\pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace) noreturn {
        \\    _ = stack_trace;
        \\    if (std.mem.eql(u8, message, "integer cast truncated bits")) {
        \\        std.process.exit(126); // good
        \\    }
        \\    std.process.exit(0); // test failed
        \\}
        \\pub fn main() void {
        \\    var x = @splat(4, @as(u32, 0x80000000));
        \\    var y = @intCast(V(4, i32), x);
        \\    _ = y;
        \\}
    );

    cases.addRuntimeSafety("signed-unsigned vector cast",
        \\const std = @import("std");
        \\const V = @import("std").meta.Vector;
        \\pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace) noreturn {
        \\    _ = stack_trace;
        \\    if (std.mem.eql(u8, message, "attempt to cast negative value to unsigned integer")) {
        \\        std.process.exit(126); // good
        \\    }
        \\    std.process.exit(0); // test failed
        \\}
        \\pub fn main() void {
        \\    var x = @splat(4, @as(i32, -2147483647));
        \\    var y = @intCast(V(4, u32), x);
        \\    _ = y;
        \\}
    );

    cases.addRuntimeSafety("shift left by huge amount",
        \\const std = @import("std");
        \\pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace) noreturn {
        \\    _ = stack_trace;
        \\    if (std.mem.eql(u8, message, "shift amount is greater than the type size")) {
        \\        std.process.exit(126); // good
        \\    }
        \\    std.process.exit(0); // test failed
        \\}
        \\pub fn main() void {
        \\    var x: u24 = 42;
        \\    var y: u5 = 24;
        \\    var z = x >> y;
        \\    _ = z;
        \\}
    );

    cases.addRuntimeSafety("shift right by huge amount",
        \\const std = @import("std");
        \\pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace) noreturn {
        \\    _ = stack_trace;
        \\    if (std.mem.eql(u8, message, "shift amount is greater than the type size")) {
        \\        std.process.exit(126); // good
        \\    }
        \\    std.process.exit(0); // test failed
        \\}
        \\pub fn main() void {
        \\    var x: u24 = 42;
        \\    var y: u5 = 24;
        \\    var z = x << y;
        \\    _ = z;
        \\}
    );

    cases.addRuntimeSafety("slice sentinel mismatch - optional pointers",
        \\const std = @import("std");
        \\pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace) noreturn {
        \\    _ = stack_trace;
        \\    if (std.mem.eql(u8, message, "sentinel mismatch")) {
        \\        std.process.exit(126); // good
        \\    }
        \\    std.process.exit(0); // test failed
        \\}
        \\pub fn main() void {
        \\    var buf: [4]?*i32 = undefined;
        \\    const slice = buf[0..3 :null];
        \\    _ = slice;
        \\}
    );

    cases.addRuntimeSafety("slice sentinel mismatch - floats",
        \\const std = @import("std");
        \\pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace) noreturn {
        \\    _ = stack_trace;
        \\    if (std.mem.eql(u8, message, "sentinel mismatch")) {
        \\        std.process.exit(126); // good
        \\    }
        \\    std.process.exit(0); // test failed
        \\}
        \\pub fn main() void {
        \\    var buf: [4]f32 = undefined;
        \\    const slice = buf[0..3 :1.2];
        \\    _ = slice;
        \\}
    );

    cases.addRuntimeSafety("pointer slice sentinel mismatch",
        \\const std = @import("std");
        \\pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace) noreturn {
        \\    _ = stack_trace;
        \\    if (std.mem.eql(u8, message, "sentinel mismatch")) {
        \\        std.process.exit(126); // good
        \\    }
        \\    std.process.exit(0); // test failed
        \\}
        \\pub fn main() void {
        \\    var buf: [4]u8 = undefined;
        \\    const ptr: [*]u8 = &buf;
        \\    const slice = ptr[0..3 :0];
        \\    _ = slice;
        \\}
    );

    cases.addRuntimeSafety("slice slice sentinel mismatch",
        \\const std = @import("std");
        \\pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace) noreturn {
        \\    _ = stack_trace;
        \\    if (std.mem.eql(u8, message, "sentinel mismatch")) {
        \\        std.process.exit(126); // good
        \\    }
        \\    std.process.exit(0); // test failed
        \\}
        \\pub fn main() void {
        \\    var buf: [4]u8 = undefined;
        \\    const slice = buf[0..];
        \\    const slice2 = slice[0..3 :0];
        \\    _ = slice2;
        \\}
    );

    cases.addRuntimeSafety("array slice sentinel mismatch",
        \\const std = @import("std");
        \\pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace) noreturn {
        \\    _ = stack_trace;
        \\    if (std.mem.eql(u8, message, "sentinel mismatch")) {
        \\        std.process.exit(126); // good
        \\    }
        \\    std.process.exit(0); // test failed
        \\}
        \\pub fn main() void {
        \\    var buf: [4]u8 = undefined;
        \\    const slice = buf[0..3 :0];
        \\    _ = slice;
        \\}
    );

    cases.addRuntimeSafety("intToPtr with misaligned address",
        \\const std = @import("std");
        \\pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace) noreturn {
        \\    _ = stack_trace;
        \\    if (std.mem.eql(u8, message, "incorrect alignment")) {
        \\        std.os.exit(126); // good
        \\    }
        \\    std.os.exit(0); // test failed
        \\}
        \\pub fn main() void {
        \\    var x: usize = 5;
        \\    var y = @intToPtr([*]align(4) u8, x);
        \\    _ = y;
        \\}
    );

    cases.addRuntimeSafety("resuming a non-suspended function which never been suspended",
        \\const std = @import("std");
        \\pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace) noreturn {
        \\    _ = message;
        \\    _ = stack_trace;
        \\    std.os.exit(126);
        \\}
        \\fn foo() void {
        \\    var f = async bar(@frame());
        \\    _ = f;
        \\    std.os.exit(0);
        \\}
        \\
        \\fn bar(frame: anyframe) void {
        \\    suspend {
        \\        resume frame;
        \\    }
        \\    std.os.exit(0);
        \\}
        \\
        \\pub fn main() void {
        \\    _ = async foo();
        \\}
    );

    cases.addRuntimeSafety("resuming a non-suspended function which has been suspended and resumed",
        \\const std = @import("std");
        \\pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace) noreturn {
        \\    _ = message;
        \\    _ = stack_trace;
        \\    std.os.exit(126);
        \\}
        \\fn foo() void {
        \\    suspend {
        \\        global_frame = @frame();
        \\    }
        \\    var f = async bar(@frame());
        \\    _ = f;
        \\    std.os.exit(0);
        \\}
        \\
        \\fn bar(frame: anyframe) void {
        \\    suspend {
        \\        resume frame;
        \\    }
        \\    std.os.exit(0);
        \\}
        \\
        \\var global_frame: anyframe = undefined;
        \\pub fn main() void {
        \\    _ = async foo();
        \\    resume global_frame;
        \\    std.os.exit(0);
        \\}
    );

    cases.addRuntimeSafety("nosuspend function call, callee suspends",
        \\const std = @import("std");
        \\pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace) noreturn {
        \\    _ = message;
        \\    _ = stack_trace;
        \\    std.os.exit(126);
        \\}
        \\pub fn main() void {
        \\    _ = nosuspend add(101, 100);
        \\}
        \\fn add(a: i32, b: i32) i32 {
        \\    if (a > 100) {
        \\        suspend {}
        \\    }
        \\    return a + b;
        \\}
    );

    cases.addRuntimeSafety("awaiting twice",
        \\const std = @import("std");
        \\pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace) noreturn {
        \\    _ = message;
        \\    _ = stack_trace;
        \\    std.os.exit(126);
        \\}
        \\var frame: anyframe = undefined;
        \\
        \\pub fn main() void {
        \\    _ = async amain();
        \\    resume frame;
        \\}
        \\
        \\fn amain() void {
        \\    var f = async func();
        \\    await f;
        \\    await f;
        \\}
        \\
        \\fn func() void {
        \\    suspend {
        \\        frame = @frame();
        \\    }
        \\}
    );

    cases.addRuntimeSafety("@asyncCall with too small a frame",
        \\const std = @import("std");
        \\pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace) noreturn {
        \\    _ = message;
        \\    _ = stack_trace;
        \\    std.os.exit(126);
        \\}
        \\pub fn main() void {
        \\    var bytes: [1]u8 align(16) = undefined;
        \\    var ptr = other;
        \\    var frame = @asyncCall(&bytes, {}, ptr, .{});
        \\    _ = frame;
        \\}
        \\fn other() callconv(.Async) void {
        \\    suspend {}
        \\}
    );

    cases.addRuntimeSafety("resuming a function which is awaiting a frame",
        \\const std = @import("std");
        \\pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace) noreturn {
        \\    _ = message;
        \\    _ = stack_trace;
        \\    std.os.exit(126);
        \\}
        \\pub fn main() void {
        \\    var frame = async first();
        \\    resume frame;
        \\}
        \\fn first() void {
        \\    var frame = async other();
        \\    await frame;
        \\}
        \\fn other() void {
        \\    suspend {}
        \\}
    );

    cases.addRuntimeSafety("resuming a function which is awaiting a call",
        \\const std = @import("std");
        \\pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace) noreturn {
        \\    _ = message;
        \\    _ = stack_trace;
        \\    std.os.exit(126);
        \\}
        \\pub fn main() void {
        \\    var frame = async first();
        \\    resume frame;
        \\}
        \\fn first() void {
        \\    other();
        \\}
        \\fn other() void {
        \\    suspend {}
        \\}
    );

    cases.addRuntimeSafety("invalid resume of async function",
        \\const std = @import("std");
        \\pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace) noreturn {
        \\    _ = message;
        \\    _ = stack_trace;
        \\    std.os.exit(126);
        \\}
        \\pub fn main() void {
        \\    var p = async suspendOnce();
        \\    resume p; //ok
        \\    resume p; //bad
        \\}
        \\fn suspendOnce() void {
        \\    suspend {}
        \\}
    );

    cases.addRuntimeSafety(".? operator on null pointer",
        \\const std = @import("std");
        \\pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace) noreturn {
        \\    _ = message;
        \\    _ = stack_trace;
        \\    std.os.exit(126);
        \\}
        \\pub fn main() void {
        \\    var ptr: ?*i32 = null;
        \\    var b = ptr.?;
        \\    _ = b;
        \\}
    );

    cases.addRuntimeSafety(".? operator on C pointer",
        \\const std = @import("std");
        \\pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace) noreturn {
        \\    _ = message;
        \\    _ = stack_trace;
        \\    std.os.exit(126);
        \\}
        \\pub fn main() void {
        \\    var ptr: [*c]i32 = null;
        \\    var b = ptr.?;
        \\    _ = b;
        \\}
    );

    cases.addRuntimeSafety("@intToPtr address zero to non-optional pointer",
        \\const std = @import("std");
        \\pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace) noreturn {
        \\    _ = message;
        \\    _ = stack_trace;
        \\    std.os.exit(126);
        \\}
        \\pub fn main() void {
        \\    var zero: usize = 0;
        \\    var b = @intToPtr(*i32, zero);
        \\    _ = b;
        \\}
    );

    cases.addRuntimeSafety("@intToPtr address zero to non-optional byte-aligned pointer",
        \\const std = @import("std");
        \\pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace) noreturn {
        \\    _ = message;
        \\    _ = stack_trace;
        \\    std.os.exit(126);
        \\}
        \\pub fn main() void {
        \\    var zero: usize = 0;
        \\    var b = @intToPtr(*u8, zero);
        \\    _ = b;
        \\}
    );

    cases.addRuntimeSafety("pointer casting null to non-optional pointer",
        \\const std = @import("std");
        \\pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace) noreturn {
        \\    _ = message;
        \\    _ = stack_trace;
        \\    std.os.exit(126);
        \\}
        \\pub fn main() void {
        \\    var c_ptr: [*c]u8 = 0;
        \\    var zig_ptr: *u8 = c_ptr;
        \\    _ = zig_ptr;
        \\}
    );

    cases.addRuntimeSafety("@intToEnum - no matching tag value",
        \\const std = @import("std");
        \\pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace) noreturn {
        \\    _ = message;
        \\    _ = stack_trace;
        \\    std.os.exit(126);
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
        \\fn baz(_: Foo) void {}
    );

    cases.addRuntimeSafety("@floatToInt cannot fit - negative to unsigned",
        \\const std = @import("std");
        \\pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace) noreturn {
        \\    _ = message;
        \\    _ = stack_trace;
        \\    std.os.exit(126);
        \\}
        \\pub fn main() void {
        \\    baz(bar(-1.1));
        \\}
        \\fn bar(a: f32) u8 {
        \\    return @floatToInt(u8, a);
        \\}
        \\fn baz(_: u8) void { }
    );

    cases.addRuntimeSafety("@floatToInt cannot fit - negative out of range",
        \\const std = @import("std");
        \\pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace) noreturn {
        \\    _ = message;
        \\    _ = stack_trace;
        \\    std.os.exit(126);
        \\}
        \\pub fn main() void {
        \\    baz(bar(-129.1));
        \\}
        \\fn bar(a: f32) i8 {
        \\    return @floatToInt(i8, a);
        \\}
        \\fn baz(_: i8) void { }
    );

    cases.addRuntimeSafety("@floatToInt cannot fit - positive out of range",
        \\const std = @import("std");
        \\pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace) noreturn {
        \\    _ = message;
        \\    _ = stack_trace;
        \\    std.os.exit(126);
        \\}
        \\pub fn main() void {
        \\    baz(bar(256.2));
        \\}
        \\fn bar(a: f32) u8 {
        \\    return @floatToInt(u8, a);
        \\}
        \\fn baz(_: u8) void { }
    );

    cases.addRuntimeSafety("calling panic",
        \\const std = @import("std");
        \\pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace) noreturn {
        \\    _ = message;
        \\    _ = stack_trace;
        \\    std.os.exit(126);
        \\}
        \\pub fn main() void {
        \\    @panic("oh no");
        \\}
    );

    cases.addRuntimeSafety("out of bounds slice access",
        \\const std = @import("std");
        \\pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace) noreturn {
        \\    _ = message;
        \\    _ = stack_trace;
        \\    std.os.exit(126);
        \\}
        \\pub fn main() void {
        \\    const a = [_]i32{1, 2, 3, 4};
        \\    baz(bar(&a));
        \\}
        \\fn bar(a: []const i32) i32 {
        \\    return a[4];
        \\}
        \\fn baz(_: i32) void { }
    );

    cases.addRuntimeSafety("integer addition overflow",
        \\const std = @import("std");
        \\pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace) noreturn {
        \\    _ = message;
        \\    _ = stack_trace;
        \\    std.os.exit(126);
        \\}
        \\pub fn main() !void {
        \\    const x = add(65530, 10);
        \\    if (x == 0) return error.Whatever;
        \\}
        \\fn add(a: u16, b: u16) u16 {
        \\    return a + b;
        \\}
    );

    cases.addRuntimeSafety("vector integer addition overflow",
        \\const std = @import("std");
        \\pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace) noreturn {
        \\    _ = message;
        \\    _ = stack_trace;
        \\    std.os.exit(126);
        \\}
        \\pub fn main() void {
        \\    var a: std.meta.Vector(4, i32) = [_]i32{ 1, 2, 2147483643, 4 };
        \\    var b: std.meta.Vector(4, i32) = [_]i32{ 5, 6, 7, 8 };
        \\    const x = add(a, b);
        \\    _ = x;
        \\}
        \\fn add(a: std.meta.Vector(4, i32), b: std.meta.Vector(4, i32)) std.meta.Vector(4, i32) {
        \\    return a + b;
        \\}
    );

    cases.addRuntimeSafety("vector integer subtraction overflow",
        \\const std = @import("std");
        \\pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace) noreturn {
        \\    _ = message;
        \\    _ = stack_trace;
        \\    std.os.exit(126);
        \\}
        \\pub fn main() void {
        \\    var a: std.meta.Vector(4, u32) = [_]u32{ 1, 2, 8, 4 };
        \\    var b: std.meta.Vector(4, u32) = [_]u32{ 5, 6, 7, 8 };
        \\    const x = sub(b, a);
        \\    _ = x;
        \\}
        \\fn sub(a: std.meta.Vector(4, u32), b: std.meta.Vector(4, u32)) std.meta.Vector(4, u32) {
        \\    return a - b;
        \\}
    );

    cases.addRuntimeSafety("vector integer multiplication overflow",
        \\const std = @import("std");
        \\pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace) noreturn {
        \\    _ = message;
        \\    _ = stack_trace;
        \\    std.os.exit(126);
        \\}
        \\pub fn main() void {
        \\    var a: std.meta.Vector(4, u8) = [_]u8{ 1, 2, 200, 4 };
        \\    var b: std.meta.Vector(4, u8) = [_]u8{ 5, 6, 2, 8 };
        \\    const x = mul(b, a);
        \\    _ = x;
        \\}
        \\fn mul(a: std.meta.Vector(4, u8), b: std.meta.Vector(4, u8)) std.meta.Vector(4, u8) {
        \\    return a * b;
        \\}
    );

    cases.addRuntimeSafety("vector integer negation overflow",
        \\const std = @import("std");
        \\pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace) noreturn {
        \\    _ = message;
        \\    _ = stack_trace;
        \\    std.os.exit(126);
        \\}
        \\pub fn main() void {
        \\    var a: std.meta.Vector(4, i16) = [_]i16{ 1, -32768, 200, 4 };
        \\    const x = neg(a);
        \\    _ = x;
        \\}
        \\fn neg(a: std.meta.Vector(4, i16)) std.meta.Vector(4, i16) {
        \\    return -a;
        \\}
    );

    cases.addRuntimeSafety("integer subtraction overflow",
        \\const std = @import("std");
        \\pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace) noreturn {
        \\    _ = message;
        \\    _ = stack_trace;
        \\    std.os.exit(126);
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
        \\const std = @import("std");
        \\pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace) noreturn {
        \\    _ = message;
        \\    _ = stack_trace;
        \\    std.os.exit(126);
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
        \\const std = @import("std");
        \\pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace) noreturn {
        \\    _ = message;
        \\    _ = stack_trace;
        \\    std.os.exit(126);
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
        \\const std = @import("std");
        \\pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace) noreturn {
        \\    _ = message;
        \\    _ = stack_trace;
        \\    std.os.exit(126);
        \\}
        \\pub fn main() !void {
        \\    const x = div(-32768, -1);
        \\    if (x == 32767) return error.Whatever;
        \\}
        \\fn div(a: i16, b: i16) i16 {
        \\    return @divTrunc(a, b);
        \\}
    );

    cases.addRuntimeSafety("signed integer division overflow - vectors",
        \\const std = @import("std");
        \\pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace) noreturn {
        \\    _ = message;
        \\    _ = stack_trace;
        \\    std.os.exit(126);
        \\}
        \\pub fn main() !void {
        \\    var a: std.meta.Vector(4, i16) = [_]i16{ 1, 2, -32768, 4 };
        \\    var b: std.meta.Vector(4, i16) = [_]i16{ 1, 2, -1, 4 };
        \\    const x = div(a, b);
        \\    if (x[2] == 32767) return error.Whatever;
        \\}
        \\fn div(a: std.meta.Vector(4, i16), b: std.meta.Vector(4, i16)) std.meta.Vector(4, i16) {
        \\    return @divTrunc(a, b);
        \\}
    );

    cases.addRuntimeSafety("signed shift left overflow",
        \\const std = @import("std");
        \\pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace) noreturn {
        \\    _ = message;
        \\    _ = stack_trace;
        \\    std.os.exit(126);
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
        \\const std = @import("std");
        \\pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace) noreturn {
        \\    _ = message;
        \\    _ = stack_trace;
        \\    std.os.exit(126);
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
        \\const std = @import("std");
        \\pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace) noreturn {
        \\    _ = message;
        \\    _ = stack_trace;
        \\    std.os.exit(126);
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
        \\const std = @import("std");
        \\pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace) noreturn {
        \\    _ = message;
        \\    _ = stack_trace;
        \\    std.os.exit(126);
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
        \\const std = @import("std");
        \\pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace) noreturn {
        \\    _ = message;
        \\    _ = stack_trace;
        \\    std.os.exit(126);
        \\}
        \\pub fn main() void {
        \\    const x = div0(999, 0);
        \\    _ = x;
        \\}
        \\fn div0(a: i32, b: i32) i32 {
        \\    return @divTrunc(a, b);
        \\}
    );

    cases.addRuntimeSafety("integer division by zero - vectors",
        \\const std = @import("std");
        \\pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace) noreturn {
        \\    _ = message;
        \\    _ = stack_trace;
        \\    std.os.exit(126);
        \\}
        \\pub fn main() void {
        \\    var a: std.meta.Vector(4, i32) = [4]i32{111, 222, 333, 444};
        \\    var b: std.meta.Vector(4, i32) = [4]i32{111, 0, 333, 444};
        \\    const x = div0(a, b);
        \\    _ = x;
        \\}
        \\fn div0(a: std.meta.Vector(4, i32), b: std.meta.Vector(4, i32)) std.meta.Vector(4, i32) {
        \\    return @divTrunc(a, b);
        \\}
    );

    cases.addRuntimeSafety("exact division failure",
        \\const std = @import("std");
        \\pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace) noreturn {
        \\    _ = message;
        \\    _ = stack_trace;
        \\    std.os.exit(126);
        \\}
        \\pub fn main() !void {
        \\    const x = divExact(10, 3);
        \\    if (x == 0) return error.Whatever;
        \\}
        \\fn divExact(a: i32, b: i32) i32 {
        \\    return @divExact(a, b);
        \\}
    );

    cases.addRuntimeSafety("exact division failure - vectors",
        \\const std = @import("std");
        \\pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace) noreturn {
        \\    _ = message;
        \\    _ = stack_trace;
        \\    std.os.exit(126);
        \\}
        \\pub fn main() !void {
        \\    var a: std.meta.Vector(4, i32) = [4]i32{111, 222, 333, 444};
        \\    var b: std.meta.Vector(4, i32) = [4]i32{111, 222, 333, 441};
        \\    const x = divExact(a, b);
        \\    _ = x;
        \\}
        \\fn divExact(a: std.meta.Vector(4, i32), b: std.meta.Vector(4, i32)) std.meta.Vector(4, i32) {
        \\    return @divExact(a, b);
        \\}
    );

    cases.addRuntimeSafety("cast []u8 to bigger slice of wrong size",
        \\const std = @import("std");
        \\pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace) noreturn {
        \\    _ = message;
        \\    _ = stack_trace;
        \\    std.os.exit(126);
        \\}
        \\pub fn main() !void {
        \\    const x = widenSlice(&[_]u8{1, 2, 3, 4, 5});
        \\    if (x.len == 0) return error.Whatever;
        \\}
        \\fn widenSlice(slice: []align(1) const u8) []align(1) const i32 {
        \\    return std.mem.bytesAsSlice(i32, slice);
        \\}
    );

    cases.addRuntimeSafety("value does not fit in shortening cast",
        \\const std = @import("std");
        \\pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace) noreturn {
        \\    _ = message;
        \\    _ = stack_trace;
        \\    std.os.exit(126);
        \\}
        \\pub fn main() !void {
        \\    const x = shorten_cast(200);
        \\    if (x == 0) return error.Whatever;
        \\}
        \\fn shorten_cast(x: i32) i8 {
        \\    return @intCast(i8, x);
        \\}
    );

    cases.addRuntimeSafety("value does not fit in shortening cast - u0",
        \\const std = @import("std");
        \\pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace) noreturn {
        \\    _ = message;
        \\    _ = stack_trace;
        \\    std.os.exit(126);
        \\}
        \\pub fn main() !void {
        \\    const x = shorten_cast(1);
        \\    if (x == 0) return error.Whatever;
        \\}
        \\fn shorten_cast(x: u8) u0 {
        \\    return @intCast(u0, x);
        \\}
    );

    cases.addRuntimeSafety("signed integer not fitting in cast to unsigned integer",
        \\const std = @import("std");
        \\pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace) noreturn {
        \\    _ = message;
        \\    _ = stack_trace;
        \\    std.os.exit(126);
        \\}
        \\pub fn main() !void {
        \\    const x = unsigned_cast(-10);
        \\    if (x == 0) return error.Whatever;
        \\}
        \\fn unsigned_cast(x: i32) u32 {
        \\    return @intCast(u32, x);
        \\}
    );

    cases.addRuntimeSafety("signed integer not fitting in cast to unsigned integer - widening",
        \\const std = @import("std");
        \\pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace) noreturn {
        \\    _ = message;
        \\    _ = stack_trace;
        \\    std.os.exit(126);
        \\}
        \\pub fn main() void {
        \\    var value: c_short = -1;
        \\    var casted = @intCast(u32, value);
        \\    _ = casted;
        \\}
    );

    cases.addRuntimeSafety("unsigned integer not fitting in cast to signed integer - same bit count",
        \\const std = @import("std");
        \\pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace) noreturn {
        \\    _ = message;
        \\    _ = stack_trace;
        \\    std.os.exit(126);
        \\}
        \\pub fn main() void {
        \\    var value: u8 = 245;
        \\    var casted = @intCast(i8, value);
        \\    _ = casted;
        \\}
    );

    cases.addRuntimeSafety("unwrap error",
        \\const std = @import("std");
        \\pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace) noreturn {
        \\    _ = stack_trace;
        \\    if (std.mem.eql(u8, message, "attempt to unwrap error: Whatever")) {
        \\        std.os.exit(126); // good
        \\    }
        \\    std.os.exit(0); // test failed
        \\}
        \\pub fn main() void {
        \\    bar() catch unreachable;
        \\}
        \\fn bar() !void {
        \\    return error.Whatever;
        \\}
    );

    cases.addRuntimeSafety("cast integer to global error and no code matches",
        \\const std = @import("std");
        \\pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace) noreturn {
        \\    _ = message;
        \\    _ = stack_trace;
        \\    std.os.exit(126);
        \\}
        \\pub fn main() void {
        \\    bar(9999) catch {};
        \\}
        \\fn bar(x: u16) anyerror {
        \\    return @intToError(x);
        \\}
    );

    cases.addRuntimeSafety("@errSetCast error not present in destination",
        \\const std = @import("std");
        \\pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace) noreturn {
        \\    _ = message;
        \\    _ = stack_trace;
        \\    std.os.exit(126);
        \\}
        \\const Set1 = error{A, B};
        \\const Set2 = error{A, C};
        \\pub fn main() void {
        \\    foo(Set1.B) catch {};
        \\}
        \\fn foo(set1: Set1) Set2 {
        \\    return @errSetCast(Set2, set1);
        \\}
    );

    cases.addRuntimeSafety("@alignCast misaligned",
        \\const std = @import("std");
        \\pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace) noreturn {
        \\    _ = message;
        \\    _ = stack_trace;
        \\    std.os.exit(126);
        \\}
        \\pub fn main() !void {
        \\    var array align(4) = [_]u32{0x11111111, 0x11111111};
        \\    const bytes = std.mem.sliceAsBytes(array[0..]);
        \\    if (foo(bytes) != 0x11111111) return error.Wrong;
        \\}
        \\fn foo(bytes: []u8) u32 {
        \\    const slice4 = bytes[1..5];
        \\    const int_slice = std.mem.bytesAsSlice(u32, @alignCast(4, slice4));
        \\    return int_slice[0];
        \\}
    );

    cases.addRuntimeSafety("bad union field access",
        \\const std = @import("std");
        \\pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace) noreturn {
        \\    _ = message;
        \\    _ = stack_trace;
        \\    std.os.exit(126);
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

    // @intCast a runtime integer to u0 actually results in a comptime-known value,
    // but we still emit a safety check to ensure the integer was 0 and thus
    // did not truncate information.
    cases.addRuntimeSafety("@intCast to u0",
        \\const std = @import("std");
        \\pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace) noreturn {
        \\    _ = message;
        \\    _ = stack_trace;
        \\    std.os.exit(126);
        \\}
        \\
        \\pub fn main() void {
        \\    bar(1, 1);
        \\}
        \\
        \\fn bar(one: u1, not_zero: i32) void {
        \\    var x = one << @intCast(u0, not_zero);
        \\    _ = x;
        \\}
    );

    // This case makes sure that the code compiles and runs. There is not actually a special
    // runtime safety check having to do specifically with error return traces across suspend points.
    cases.addRuntimeSafety("error return trace across suspend points",
        \\const std = @import("std");
        \\
        \\pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace) noreturn {
        \\    _ = message;
        \\    _ = stack_trace;
        \\    std.os.exit(126);
        \\}
        \\
        \\var failing_frame: @Frame(failing) = undefined;
        \\
        \\pub fn main() void {
        \\    const p = nonFailing();
        \\    resume p;
        \\    const p2 = async printTrace(p);
        \\    _ = p2;
        \\}
        \\
        \\fn nonFailing() anyframe->anyerror!void {
        \\    failing_frame = async failing();
        \\    return &failing_frame;
        \\}
        \\
        \\fn failing() anyerror!void {
        \\    suspend {}
        \\    return second();
        \\}
        \\
        \\fn second() callconv(.Async) anyerror!void {
        \\    return error.Fail;
        \\}
        \\
        \\fn printTrace(p: anyframe->anyerror!void) void {
        \\    (await p) catch unreachable;
        \\}
    );

    // Slicing a C pointer returns a non-allowzero slice, thus we need to emit
    // a safety check to ensure the pointer is not null.
    cases.addRuntimeSafety("slicing null C pointer",
        \\const std = @import("std");
        \\pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace) noreturn {
        \\    _ = message;
        \\    _ = stack_trace;
        \\    std.os.exit(126);
        \\}
        \\
        \\pub fn main() void {
        \\    var ptr: [*c]const u32 = null;
        \\    var slice = ptr[0..3];
        \\    _ = slice;
        \\}
    );
}

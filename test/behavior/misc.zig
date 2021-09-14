const std = @import("std");
const expect = std.testing.expect;
const expectEqualSlices = std.testing.expectEqualSlices;
const expectEqualStrings = std.testing.expectEqualStrings;
const mem = std.mem;
const builtin = @import("builtin");

test "memcpy and memset intrinsics" {
    var foo: [20]u8 = undefined;
    var bar: [20]u8 = undefined;

    @memset(&foo, 'A', foo.len);
    @memcpy(&bar, &foo, bar.len);

    if (bar[11] != 'A') unreachable;
}

test "slicing" {
    var array: [20]i32 = undefined;

    array[5] = 1234;

    var slice = array[5..10];

    if (slice.len != 5) unreachable;

    const ptr = &slice[0];
    if (ptr.* != 1234) unreachable;

    var slice_rest = array[10..];
    if (slice_rest.len != 10) unreachable;
}

test "constant equal function pointers" {
    const alias = emptyFn;
    try expect(comptime x: {
        break :x emptyFn == alias;
    });
}

fn emptyFn() void {}

test "string escapes" {
    try expectEqualStrings("\"", "\x22");
    try expectEqualStrings("\'", "\x27");
    try expectEqualStrings("\n", "\x0a");
    try expectEqualStrings("\r", "\x0d");
    try expectEqualStrings("\t", "\x09");
    try expectEqualStrings("\\", "\x5c");
    try expectEqualStrings("\u{1234}\u{069}\u{1}", "\xe1\x88\xb4\x69\x01");
}

test "multiline string literal is null terminated" {
    const s1 =
        \\one
        \\two)
        \\three
    ;
    const s2 = "one\ntwo)\nthree";
    try expect(std.cstr.cmp(s1, s2) == 0);
}

const global_a: i32 = 1234;
const global_b: *const i32 = &global_a;
const global_c: *const f32 = @ptrCast(*const f32, global_b);
test "compile time global reinterpret" {
    const d = @ptrCast(*const i32, global_c);
    try expect(d.* == 1234);
}

test "explicit cast maybe pointers" {
    const a: ?*i32 = undefined;
    const b: ?*f32 = @ptrCast(?*f32, a);
    _ = b;
}

test "generic malloc free" {
    const a = memAlloc(u8, 10) catch unreachable;
    memFree(u8, a);
}
var some_mem: [100]u8 = undefined;
fn memAlloc(comptime T: type, n: usize) anyerror![]T {
    return @ptrCast([*]T, &some_mem[0])[0..n];
}
fn memFree(comptime T: type, memory: []T) void {
    _ = memory;
}

test "cast undefined" {
    const array: [100]u8 = undefined;
    const slice = @as([]const u8, &array);
    testCastUndefined(slice);
}
fn testCastUndefined(x: []const u8) void {
    _ = x;
}

test "implicit cast after unreachable" {
    try expect(outer() == 1234);
}
fn inner() i32 {
    return 1234;
}
fn outer() i64 {
    return inner();
}

test "constant enum initialization with differing sizes" {
    try test3_1(test3_foo);
    try test3_2(test3_bar);
}
const Test3Foo = union(enum) {
    One: void,
    Two: f32,
    Three: Test3Point,
};
const Test3Point = struct {
    x: i32,
    y: i32,
};
const test3_foo = Test3Foo{
    .Three = Test3Point{
        .x = 3,
        .y = 4,
    },
};
const test3_bar = Test3Foo{ .Two = 13 };
fn test3_1(f: Test3Foo) !void {
    switch (f) {
        Test3Foo.Three => |pt| {
            try expect(pt.x == 3);
            try expect(pt.y == 4);
        },
        else => unreachable,
    }
}
fn test3_2(f: Test3Foo) !void {
    switch (f) {
        Test3Foo.Two => |x| {
            try expect(x == 13);
        },
        else => unreachable,
    }
}

test "take address of parameter" {
    try testTakeAddressOfParameter(12.34);
}
fn testTakeAddressOfParameter(f: f32) !void {
    const f_ptr = &f;
    try expect(f_ptr.* == 12.34);
}

test "pointer comparison" {
    const a = @as([]const u8, "a");
    const b = &a;
    try expect(ptrEql(b, b));
}
fn ptrEql(a: *const []const u8, b: *const []const u8) bool {
    return a == b;
}

test "string concatenation" {
    const a = "OK" ++ " IT " ++ "WORKED";
    const b = "OK IT WORKED";

    comptime try expect(@TypeOf(a) == *const [12:0]u8);
    comptime try expect(@TypeOf(b) == *const [12:0]u8);

    const len = mem.len(b);
    const len_with_null = len + 1;
    {
        var i: u32 = 0;
        while (i < len_with_null) : (i += 1) {
            try expect(a[i] == b[i]);
        }
    }
    try expect(a[len] == 0);
    try expect(b[len] == 0);
}

test "pointer to void return type" {
    testPointerToVoidReturnType() catch unreachable;
}
fn testPointerToVoidReturnType() anyerror!void {
    const a = testPointerToVoidReturnType2();
    return a.*;
}
const test_pointer_to_void_return_type_x = void{};
fn testPointerToVoidReturnType2() *const void {
    return &test_pointer_to_void_return_type_x;
}

test "array 2D const double ptr" {
    const rect_2d_vertexes = [_][1]f32{
        [_]f32{1.0},
        [_]f32{2.0},
    };
    try testArray2DConstDoublePtr(&rect_2d_vertexes[0][0]);
}

fn testArray2DConstDoublePtr(ptr: *const f32) !void {
    const ptr2 = @ptrCast([*]const f32, ptr);
    try expect(ptr2[0] == 1.0);
    try expect(ptr2[1] == 2.0);
}

test "double implicit cast in same expression" {
    var x = @as(i32, @as(u16, nine()));
    try expect(x == 9);
}
fn nine() u8 {
    return 9;
}

test "global variable initialized to global variable array element" {
    try expect(global_ptr == &gdt[0]);
}
const GDTEntry = struct {
    field: i32,
};
var gdt = [_]GDTEntry{
    GDTEntry{ .field = 1 },
    GDTEntry{ .field = 2 },
};
var global_ptr = &gdt[0];

// can't really run this test but we can make sure it has no compile error
// and generates code
const vram = @intToPtr([*]volatile u8, 0x20000000)[0..0x8000];
export fn writeToVRam() void {
    vram[0] = 'X';
}

const OpaqueA = opaque {};
const OpaqueB = opaque {};
test "opaque types" {
    try expect(*OpaqueA != *OpaqueB);
    try expect(mem.eql(u8, @typeName(OpaqueA), "OpaqueA"));
    try expect(mem.eql(u8, @typeName(OpaqueB), "OpaqueB"));
}

test "variable is allowed to be a pointer to an opaque type" {
    var x: i32 = 1234;
    _ = hereIsAnOpaqueType(@ptrCast(*OpaqueA, &x));
}
fn hereIsAnOpaqueType(ptr: *OpaqueA) *OpaqueA {
    var a = ptr;
    return a;
}

test "comptime if inside runtime while which unconditionally breaks" {
    testComptimeIfInsideRuntimeWhileWhichUnconditionallyBreaks(true);
    comptime testComptimeIfInsideRuntimeWhileWhichUnconditionallyBreaks(true);
}
fn testComptimeIfInsideRuntimeWhileWhichUnconditionallyBreaks(cond: bool) void {
    while (cond) {
        if (false) {}
        break;
    }
}

test "implicit comptime while" {
    while (false) {
        @compileError("bad");
    }
}

fn fnThatClosesOverLocalConst() type {
    const c = 1;
    return struct {
        fn g() i32 {
            return c;
        }
    };
}

test "function closes over local const" {
    const x = fnThatClosesOverLocalConst().g();
    try expect(x == 1);
}

const PackedStruct = packed struct {
    a: u8,
    b: u8,
};
const PackedUnion = packed union {
    a: u8,
    b: u32,
};

test "packed struct, enum, union parameters in extern function" {
    testPackedStuff(&(PackedStruct{
        .a = 1,
        .b = 2,
    }), &(PackedUnion{ .a = 1 }));
}

export fn testPackedStuff(a: *const PackedStruct, b: *const PackedUnion) void {
    if (false) {
        a;
        b;
    }
}

test "slicing zero length array" {
    const s1 = ""[0..];
    const s2 = ([_]u32{})[0..];
    try expect(s1.len == 0);
    try expect(s2.len == 0);
    try expect(mem.eql(u8, s1, ""));
    try expect(mem.eql(u32, s2, &[_]u32{}));
}

const addr1 = @ptrCast(*const u8, emptyFn);
test "comptime cast fn to ptr" {
    const addr2 = @ptrCast(*const u8, emptyFn);
    comptime try expect(addr1 == addr2);
}

test "equality compare fn ptrs" {
    var a = emptyFn;
    try expect(a == a);
}

test "self reference through fn ptr field" {
    const S = struct {
        const A = struct {
            f: fn (A) u8,
        };

        fn foo(a: A) u8 {
            _ = a;
            return 12;
        }
    };
    var a: S.A = undefined;
    a.f = S.foo;
    try expect(a.f(a) == 12);
}

test "volatile load and store" {
    var number: i32 = 1234;
    const ptr = @as(*volatile i32, &number);
    ptr.* += 1;
    try expect(ptr.* == 1235);
}

test "slice string literal has correct type" {
    comptime {
        try expect(@TypeOf("aoeu"[0..]) == *const [4:0]u8);
        const array = [_]i32{ 1, 2, 3, 4 };
        try expect(@TypeOf(array[0..]) == *const [4]i32);
    }
    var runtime_zero: usize = 0;
    comptime try expect(@TypeOf("aoeu"[runtime_zero..]) == [:0]const u8);
    const array = [_]i32{ 1, 2, 3, 4 };
    comptime try expect(@TypeOf(array[runtime_zero..]) == []const i32);
}

test "struct inside function" {
    try testStructInFn();
    comptime try testStructInFn();
}

fn testStructInFn() !void {
    const BlockKind = u32;

    const Block = struct {
        kind: BlockKind,
    };

    var block = Block{ .kind = 1234 };

    block.kind += 1;

    try expect(block.kind == 1235);
}

test "fn call returning scalar optional in equality expression" {
    try expect(getNull() == null);
}

fn getNull() ?*i32 {
    return null;
}

test "thread local variable" {
    const S = struct {
        threadlocal var t: i32 = 1234;
    };
    S.t += 1;
    try expect(S.t == 1235);
}

test "result location zero sized array inside struct field implicit cast to slice" {
    const E = struct {
        entries: []u32,
    };
    var foo = E{ .entries = &[_]u32{} };
    try expect(foo.entries.len == 0);
}

var global_foo: *i32 = undefined;

test "global variable assignment with optional unwrapping with var initialized to undefined" {
    const S = struct {
        var data: i32 = 1234;
        fn foo() ?*i32 {
            return &data;
        }
    };
    global_foo = S.foo() orelse {
        @panic("bad");
    };
    try expect(global_foo.* == 1234);
}

test "peer result location with typed parent, runtime condition, comptime prongs" {
    const S = struct {
        fn doTheTest(arg: i32) i32 {
            const st = Structy{
                .bleh = if (arg == 1) 1 else 1,
            };

            if (st.bleh == 1)
                return 1234;
            return 0;
        }

        const Structy = struct {
            bleh: i32,
        };
    };
    try expect(S.doTheTest(0) == 1234);
    try expect(S.doTheTest(1) == 1234);
}

test "nested optional field in struct" {
    const S2 = struct {
        y: u8,
    };
    const S1 = struct {
        x: ?S2,
    };
    var s = S1{
        .x = S2{ .y = 127 },
    };
    try expect(s.x.?.y == 127);
}

fn maybe(x: bool) anyerror!?u32 {
    return switch (x) {
        true => @as(u32, 42),
        else => null,
    };
}

test "result location is optional inside error union" {
    const x = maybe(true) catch unreachable;
    try expect(x.? == 42);
}

threadlocal var buffer: [11]u8 = undefined;

test "pointer to thread local array" {
    const s = "Hello world";
    std.mem.copy(u8, buffer[0..], s);
    try std.testing.expectEqualSlices(u8, buffer[0..], s);
}

test "auto created variables have correct alignment" {
    const S = struct {
        fn foo(str: [*]const u8) u32 {
            for (@ptrCast([*]align(1) const u32, str)[0..1]) |v| {
                return v;
            }
            return 0;
        }
    };
    try expect(S.foo("\x7a\x7a\x7a\x7a") == 0x7a7a7a7a);
    comptime try expect(S.foo("\x7a\x7a\x7a\x7a") == 0x7a7a7a7a);
}

extern var opaque_extern_var: opaque {};
var var_to_export: u32 = 42;
test "extern variable with non-pointer opaque type" {
    @export(var_to_export, .{ .name = "opaque_extern_var" });
    try expect(@ptrCast(*align(1) u32, &opaque_extern_var).* == 42);
}

test "lazy typeInfo value as generic parameter" {
    const S = struct {
        fn foo(args: anytype) void {
            _ = args;
        }
    };
    S.foo(@typeInfo(@TypeOf(.{})));
}

fn ZA() type {
    return struct {
        b: B(),

        const Self = @This();

        fn B() type {
            return struct {
                const Self = @This();
            };
        }
    };
}
test "non-ambiguous reference of shadowed decls" {
    try expect(ZA().B().Self != ZA().Self);
}

test "use of declaration with same name as primitive" {
    const S = struct {
        const @"u8" = u16;
        const alias = @"u8";
    };
    const a: S.u8 = 300;
    try expect(a == 300);

    const b: S.alias = 300;
    try expect(b == 300);

    const @"u8" = u16;
    const c: @"u8" = 300;
    try expect(c == 300);
}

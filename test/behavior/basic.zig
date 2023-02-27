const std = @import("std");
const builtin = @import("builtin");
const assert = std.debug.assert;
const mem = std.mem;
const expect = std.testing.expect;
const expectEqualStrings = std.testing.expectEqualStrings;

// normal comment

/// this is a documentation comment
/// doc comment line 2
fn emptyFunctionWithComments() void {}

test "empty function with comments" {
    emptyFunctionWithComments();
}

test "truncate" {
    try expect(testTruncate(0x10fd) == 0xfd);
    comptime try expect(testTruncate(0x10fd) == 0xfd);
}
fn testTruncate(x: u32) u8 {
    return @truncate(u8, x);
}

test "truncate to non-power-of-two integers" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    try testTrunc(u32, u1, 0b10101, 0b1);
    try testTrunc(u32, u1, 0b10110, 0b0);
    try testTrunc(u32, u2, 0b10101, 0b01);
    try testTrunc(u32, u2, 0b10110, 0b10);
    try testTrunc(i32, i5, -4, -4);
    try testTrunc(i32, i5, 4, 4);
    try testTrunc(i32, i5, -28, 4);
    try testTrunc(i32, i5, 28, -4);
    try testTrunc(i32, i5, std.math.maxInt(i32), -1);
}

test "truncate to non-power-of-two integers from 128-bit" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    try testTrunc(u128, u1, 0xffffffff_ffffffff_ffffffff_01010101, 0x01);
    try testTrunc(u128, u1, 0xffffffff_ffffffff_ffffffff_01010110, 0x00);
    try testTrunc(u128, u2, 0xffffffff_ffffffff_ffffffff_01010101, 0x01);
    try testTrunc(u128, u2, 0xffffffff_ffffffff_ffffffff_01010102, 0x02);
    try testTrunc(i128, i5, -4, -4);
    try testTrunc(i128, i5, 4, 4);
    try testTrunc(i128, i5, -28, 4);
    try testTrunc(i128, i5, 28, -4);
    try testTrunc(i128, i5, std.math.maxInt(i128), -1);
}

fn testTrunc(comptime Big: type, comptime Little: type, big: Big, little: Little) !void {
    try expect(@truncate(Little, big) == little);
}

const g1: i32 = 1233 + 1;
var g2: i32 = 0;

test "global variables" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    try expect(g2 == 0);
    g2 = g1;
    try expect(g2 == 1234);
}

test "comptime keyword on expressions" {
    const x: i32 = comptime x: {
        break :x 1 + 2 + 3;
    };
    try expect(x == comptime 6);
}

test "type equality" {
    try expect(*const u8 != *u8);
}

test "pointer dereferencing" {
    var x = @as(i32, 3);
    const y = &x;

    y.* += 1;

    try expect(x == 4);
    try expect(y.* == 4);
}

test "const expression eval handling of variables" {
    var x = true;
    while (x) {
        x = false;
    }
}

test "character literals" {
    try expect('\'' == single_quote);
}
const single_quote = '\'';

test "non const ptr to aliased type" {
    const int = i32;
    try expect(?*int == ?*i32);
}

test "cold function" {
    thisIsAColdFn();
    comptime thisIsAColdFn();
}

fn thisIsAColdFn() void {
    @setCold(true);
}

test "unicode escape in character literal" {
    var a: u24 = '\u{01f4a9}';
    try expect(a == 128169);
}

test "unicode character in character literal" {
    try expect('💩' == 128169);
}

fn first4KeysOfHomeRow() []const u8 {
    return "aoeu";
}

test "return string from function" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    try expect(mem.eql(u8, first4KeysOfHomeRow(), "aoeu"));
}

test "hex escape" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    try expect(mem.eql(u8, "\x68\x65\x6c\x6c\x6f", "hello"));
}

test "multiline string" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const s1 =
        \\one
        \\two)
        \\three
    ;
    const s2 = "one\ntwo)\nthree";
    try expect(mem.eql(u8, s1, s2));
}

test "multiline string comments at start" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const s1 =
        //\\one
        \\two)
        \\three
    ;
    const s2 = "two)\nthree";
    try expect(mem.eql(u8, s1, s2));
}

test "multiline string comments at end" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const s1 =
        \\one
        \\two)
        //\\three
    ;
    const s2 = "one\ntwo)";
    try expect(mem.eql(u8, s1, s2));
}

test "multiline string comments in middle" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const s1 =
        \\one
        //\\two)
        \\three
    ;
    const s2 = "one\nthree";
    try expect(mem.eql(u8, s1, s2));
}

test "multiline string comments at multiple places" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const s1 =
        \\one
        //\\two
        \\three
        //\\four
        \\five
    ;
    const s2 = "one\nthree\nfive";
    try expect(mem.eql(u8, s1, s2));
}

test "string concatenation" {
    try expect(mem.eql(u8, "OK" ++ " IT " ++ "WORKED", "OK IT WORKED"));
}

test "array mult operator" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    try expect(mem.eql(u8, "ab" ** 5, "ababababab"));
}

const OpaqueA = opaque {};
const OpaqueB = opaque {};

test "opaque types" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    try expect(*OpaqueA != *OpaqueB);

    try expect(mem.eql(u8, @typeName(OpaqueA), "behavior.basic.OpaqueA"));
    try expect(mem.eql(u8, @typeName(OpaqueB), "behavior.basic.OpaqueB"));
}

const global_a: i32 = 1234;
const global_b: *const i32 = &global_a;
const global_c: *const f32 = @ptrCast(*const f32, global_b);
test "compile time global reinterpret" {
    const d = @ptrCast(*const i32, global_c);
    try expect(d.* == 1234);
}

test "cast undefined" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const array: [100]u8 = undefined;
    const slice = @as([]const u8, &array);
    testCastUndefined(slice);
}
fn testCastUndefined(x: []const u8) void {
    _ = x;
}

test "implicit cast after unreachable" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    try expect(outer() == 1234);
}
fn inner() i32 {
    return 1234;
}
fn outer() i64 {
    return inner();
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

test "volatile load and store" {
    var number: i32 = 1234;
    const ptr = @as(*volatile i32, &number);
    ptr.* += 1;
    try expect(ptr.* == 1235);
}

fn fA() []const u8 {
    return "a";
}
fn fB() []const u8 {
    return "b";
}

test "call function pointer in struct" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    try expect(mem.eql(u8, f3(true), "a"));
    try expect(mem.eql(u8, f3(false), "b"));
}

fn f3(x: bool) []const u8 {
    var wrapper: FnPtrWrapper = .{
        .fn_ptr = fB,
    };

    if (x) {
        wrapper.fn_ptr = fA;
    }

    return wrapper.fn_ptr();
}

const FnPtrWrapper = struct {
    fn_ptr: *const fn () []const u8,
};

test "const ptr from var variable" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;

    var x: u64 = undefined;
    var y: u64 = undefined;

    x = 78;
    copy(&x, &y);

    try expect(x == y);
}

fn copy(src: *const u64, dst: *u64) void {
    dst.* = src.*;
}

test "call result of if else expression" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    try expect(mem.eql(u8, f2(true), "a"));
    try expect(mem.eql(u8, f2(false), "b"));
}
fn f2(x: bool) []const u8 {
    return (if (x) &fA else &fB)();
}

test "memcpy and memset intrinsics" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    try testMemcpyMemset();
    // TODO add comptime test coverage
    //comptime try testMemcpyMemset();
}

fn testMemcpyMemset() !void {
    var foo: [20]u8 = undefined;
    var bar: [20]u8 = undefined;

    @memset(&foo, 'A', foo.len);
    @memcpy(&bar, &foo, bar.len);

    try expect(bar[0] == 'A');
    try expect(bar[11] == 'A');
    try expect(bar[19] == 'A');
}

test "variable is allowed to be a pointer to an opaque type" {
    var x: i32 = 1234;
    _ = hereIsAnOpaqueType(@ptrCast(*OpaqueA, &x));
}
fn hereIsAnOpaqueType(ptr: *OpaqueA) *OpaqueA {
    var a = ptr;
    return a;
}

test "take address of parameter" {
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    try testTakeAddressOfParameter(12.34);
}
fn testTakeAddressOfParameter(f: f32) !void {
    const f_ptr = &f;
    try expect(f_ptr.* == 12.34);
}

test "pointer to void return type" {
    try testPointerToVoidReturnType();
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
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO

    const rect_2d_vertexes = [_][1]f32{
        [_]f32{1.0},
        [_]f32{2.0},
    };
    try testArray2DConstDoublePtr(&rect_2d_vertexes[0][0]);
}

test "array 2D const double ptr with offset" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest;

    const rect_2d_vertexes = [_][2]f32{
        [_]f32{ 3.0, 4.239 },
        [_]f32{ 1.0, 2.0 },
    };
    try testArray2DConstDoublePtr(&rect_2d_vertexes[1][0]);
}

test "array 3D const double ptr with offset" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO

    const rect_3d_vertexes = [_][2][2]f32{
        [_][2]f32{
            [_]f32{ 3.0, 4.239 },
            [_]f32{ 3.5, 7.2 },
        },
        [_][2]f32{
            [_]f32{ 3.0, 4.239 },
            [_]f32{ 1.0, 2.0 },
        },
    };
    try testArray2DConstDoublePtr(&rect_3d_vertexes[1][1][0]);
}

fn testArray2DConstDoublePtr(ptr: *const f32) !void {
    const ptr2 = @ptrCast([*]const f32, ptr);
    try expect(ptr2[0] == 1.0);
    try expect(ptr2[1] == 2.0);
}

test "double implicit cast in same expression" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    var x = @as(i32, @as(u16, nine()));
    try expect(x == 9);
}
fn nine() u8 {
    return 9;
}

test "struct inside function" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

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
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    try expect(getNull() == null);
}

fn getNull() ?*i32 {
    return null;
}

test "global variable assignment with optional unwrapping with var initialized to undefined" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

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

var global_foo: *i32 = undefined;

test "peer result location with typed parent, runtime condition, comptime prongs" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

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

test "non-ambiguous reference of shadowed decls" {
    try expect(ZA().B().Self != ZA().Self);
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

test "constant equal function pointers" {
    const alias = emptyFn;
    try expect(comptime x: {
        break :x emptyFn == alias;
    });
}

fn emptyFn() void {}

const addr1 = @ptrCast(*const u8, &emptyFn);
test "comptime cast fn to ptr" {
    const addr2 = @ptrCast(*const u8, &emptyFn);
    comptime try expect(addr1 == addr2);
}

test "equality compare fn ptrs" {
    var a = &emptyFn;
    try expect(a == a);
}

test "self reference through fn ptr field" {
    const S = struct {
        const A = struct {
            f: *const fn (A) u8,
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

test "global variable initialized to global variable array element" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

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

test "global constant is loaded with a runtime-known index" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const S = struct {
        fn doTheTest() !void {
            var index: usize = 1;
            const ptr = &pieces[index].field;
            try expect(ptr.* == 2);
        }
        const Piece = struct {
            field: i32,
        };
        const pieces = [_]Piece{ Piece{ .field = 1 }, Piece{ .field = 2 }, Piece{ .field = 3 } };
    };
    try S.doTheTest();
}

test "multiline string literal is null terminated" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;

    const s1 =
        \\one
        \\two)
        \\three
    ;
    const s2 = "one\ntwo)\nthree";
    try expect(std.cstr.cmp(s1, s2) == 0);
}

test "string escapes" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    try expectEqualStrings("\"", "\x22");
    try expectEqualStrings("\'", "\x27");
    try expectEqualStrings("\n", "\x0a");
    try expectEqualStrings("\r", "\x0d");
    try expectEqualStrings("\t", "\x09");
    try expectEqualStrings("\\", "\x5c");
    try expectEqualStrings("\u{1234}\u{069}\u{1}", "\xe1\x88\xb4\x69\x01");
}

test "explicit cast optional pointers" {
    const a: ?*i32 = undefined;
    const b: ?*f32 = @ptrCast(?*f32, a);
    _ = b;
}

test "pointer comparison" {
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest;

    const a = @as([]const u8, "a");
    const b = &a;
    try expect(ptrEql(b, b));
}
fn ptrEql(a: *const []const u8, b: *const []const u8) bool {
    return a == b;
}

test "string concatenation" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const a = "OK" ++ " IT " ++ "WORKED";
    const b = "OK IT WORKED";

    comptime try expect(@TypeOf(a) == *const [12:0]u8);
    comptime try expect(@TypeOf(b) == *const [12:0]u8);

    const len = b.len;
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

fn manyptrConcat(comptime s: [*:0]const u8) [*:0]const u8 {
    return "very " ++ s;
}

test "comptime manyptr concatenation" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const s = "epic";
    const actual = manyptrConcat(s);
    const expected = "very epic";

    const len = mem.len(actual);
    const len_with_null = len + 1;
    {
        var i: u32 = 0;
        while (i < len_with_null) : (i += 1) {
            try expect(actual[i] == expected[i]);
        }
    }
    try expect(actual[len] == 0);
    try expect(expected[len] == 0);
}

test "result location is optional inside error union" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const x = maybe(true) catch unreachable;
    try expect(x.? == 42);
}

fn maybe(x: bool) anyerror!?u32 {
    return switch (x) {
        true => @as(u32, 42),
        else => null,
    };
}

test "auto created variables have correct alignment" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

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

test "extern variable with non-pointer opaque type" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    @export(var_to_export, .{ .name = "opaque_extern_var" });
    try expect(@ptrCast(*align(1) u32, &opaque_extern_var).* == 42);
}
extern var opaque_extern_var: opaque {};
var var_to_export: u32 = 42;

test "lazy typeInfo value as generic parameter" {
    const S = struct {
        fn foo(args: anytype) void {
            _ = args;
        }
    };
    S.foo(@typeInfo(@TypeOf(.{})));
}

test "variable name containing underscores does not shadow int primitive" {
    const _u0 = 0;
    const i_8 = 0;
    const u16_ = 0;
    const i3_2 = 0;
    const u6__4 = 0;
    const i2_04_8 = 0;

    _ = _u0;
    _ = i_8;
    _ = u16_;
    _ = i3_2;
    _ = u6__4;
    _ = i2_04_8;
}

test "if expression type coercion" {
    var cond: bool = true;
    const x: u16 = if (cond) 1 else 0;
    try expect(@as(u16, x) == 1);
}

test "discarding the result of various expressions" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const S = struct {
        fn foo() !u32 {
            return 1;
        }
        fn bar() ?u32 {
            return 1;
        }
    };
    _ = S.bar() orelse {
        // do nothing
    };
    _ = S.foo() catch {
        // do nothing
    };
    _ = switch (1) {
        1 => 1,
        2 => {},
        else => return,
    };
    _ = try S.foo();
    _ = if (S.bar()) |some| some else {};
    _ = blk: {
        if (S.bar()) |some| break :blk some;
        break :blk;
    };
    _ = while (S.bar()) |some| break some else {};
    _ = for ("foo") |char| break char else {};
}

test "labeled block implicitly ends in a break" {
    var a = false;
    blk: {
        if (a) break :blk;
    }
}

test "catch in block has correct result location" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const S = struct {
        fn open() error{A}!@This() {
            return @This(){};
        }
        fn foo(_: @This()) u32 {
            return 1;
        }
    };
    const config_h_text: u32 = blk: {
        var dir = S.open() catch unreachable;
        break :blk dir.foo();
    };
    try expect(config_h_text == 1);
}

test "labeled block with runtime branch forwards its result location type to break statements" {
    const E = enum { a, b };
    var a = false;
    const e: E = blk: {
        if (a) {
            break :blk .a;
        }
        break :blk .b;
    };
    try expect(e == .b);
}

test "try in labeled block doesn't cast to wrong type" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const S = struct {
        a: u32,
        fn foo() anyerror!u32 {
            return 1;
        }
    };
    const s: ?*S = blk: {
        var a = try S.foo();

        _ = a;
        break :blk null;
    };
    _ = s;
}

test "vector initialized with array init syntax has proper type" {
    comptime {
        const actual = -@Vector(4, i32){ 1, 2, 3, 4 };
        try std.testing.expectEqual(@Vector(4, i32){ -1, -2, -3, -4 }, actual);
    }
}

test "weird array and tuple initializations" {
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const E = enum { a, b };
    const S = struct { e: E };
    var a = false;
    const b = S{ .e = .a };

    _ = &[_]S{
        if (a) .{ .e = .a } else .{ .e = .b },
    };

    if (true) return error.SkipZigTest;

    const S2 = @TypeOf(.{ false, b });
    _ = &S2{
        true,
        if (a) .{ .e = .a } else .{ .e = .b },
    };
    const S3 = @TypeOf(.{ .a = false, .b = b });
    _ = &S3{
        .a = true,
        .b = if (a) .{ .e = .a } else .{ .e = .b },
    };
}

test "array type comes from generic function" {
    const S = struct {
        fn A() type {
            return struct { a: u8 = 0 };
        }
    };
    const args = [_]S.A(){.{}};
    _ = args;
}

test "generic function uses return type of other generic function" {
    if (true) {
        // This test has been failing sporadically on the CI.
        // It's not enough to verify that it works locally; we need to diagnose why
        // it fails on the CI sometimes before turning it back on.
        // https://github.com/ziglang/zig/issues/12208
        return error.SkipZigTest;
    }
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO

    const S = struct {
        fn call(
            f: anytype,
            args: anytype,
        ) @TypeOf(@call(.auto, f, @as(@TypeOf(args), undefined))) {
            return @call(.auto, f, args);
        }

        fn func(arg: anytype) @TypeOf(arg) {
            return arg;
        }
    };
    try std.testing.expect(S.call(S.func, .{@as(u8, 1)}) == 1);
}

test "const alloc with comptime-known initializer is made comptime-known" {
    const S = struct {
        a: bool,
        b: [2]u8,
    };
    {
        const s: S = .{
            .a = false,
            .b = .{ 1, 2 },
        };
        if (s.a) @compileError("bad");
    }
    {
        const s: S = .{
            .a = false,
            .b = [2]u8{ 1, 2 },
        };
        if (s.a) @compileError("bad");
    }
    {
        const s: S = comptime .{
            .a = false,
            .b = .{ 1, 2 },
        };
        if (s.a) @compileError("bad");
    }
    {
        const Const = struct {
            limbs: []const usize,
            positive: bool,
        };
        const biggest: Const = .{
            .limbs = &([1]usize{comptime std.math.maxInt(usize)} ** 128),
            .positive = false,
        };
        if (biggest.positive) @compileError("bad");
    }
    {
        const U = union(enum) {
            a: usize,
        };
        const u: U = .{
            .a = comptime std.math.maxInt(usize),
        };
        if (u.a == 0) @compileError("bad");
    }
}

comptime {
    // coerce result ptr outside a function
    const S = struct { a: comptime_int };
    var s: S = undefined;
    s = S{ .a = 1 };
    assert(s.a == 1);
}

test "switch inside @as gets correct type" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    var a: u32 = 0;
    var b: [2]u32 = undefined;
    b[0] = @as(u32, switch (a) {
        1 => 1,
        else => 0,
    });
}

test "inline call of function with a switch inside the return statement" {
    const S = struct {
        inline fn foo(x: anytype) @TypeOf(x) {
            return switch (x) {
                1 => 1,
                else => unreachable,
            };
        }
    };
    try expect(S.foo(1) == 1);
}

test "namespace lookup ignores decl causing the lookup" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO

    if (builtin.zig_backend == .stage2_llvm) {
        // regressed with LLVM 15
        // https://github.com/ziglang/zig/issues/12681
        return error.SkipZigTest;
    }

    const S = struct {
        fn Mixin(comptime T: type) type {
            return struct {
                fn foo() void {
                    const set = std.EnumSet(T.E).init(undefined);
                    _ = set;
                }
            };
        }

        const E = enum { a, b };
        usingnamespace Mixin(@This());
    };
    _ = S.foo();
}

test "ambiguous reference error ignores current declaration" {
    const S = struct {
        const foo = 666;

        const a = @This();
        const b = struct {
            const foo = a.foo;
            const bar = struct {
                bar: u32 = b.foo,
            };

            comptime {
                _ = b.foo;
            }
        };

        usingnamespace b;
    };
    try expect(S.b.foo == 666);
}

test "pointer to zero sized global is mutable" {
    const S = struct {
        const Thing = struct {};

        var thing: Thing = undefined;
    };
    try expect(@TypeOf(&S.thing) == *S.Thing);
}

test "returning an opaque type from a function" {
    const S = struct {
        fn foo(comptime a: u32) type {
            return opaque {
                const b = a;
            };
        }
    };
    try expect(S.foo(123).b == 123);
}

test "orelse coercion as function argument" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO

    const Loc = struct { start: i32 = -1 };
    const Container = struct {
        a: ?Loc = null,
        fn init(a: Loc) @This() {
            return .{
                .a = a,
            };
        }
    };
    var optional: ?Loc = .{};
    var foo = Container.init(optional orelse .{});
    try expect(foo.a.?.start == -1);
}

test "runtime-known globals initialized with undefined" {
    const S = struct {
        var array: [10]u32 = [_]u32{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 };
        var vp: [*]u32 = undefined;
        var s: []u32 = undefined;
    };

    S.vp = &S.array;
    S.s = S.vp[0..5];

    try expect(S.s[0] == 1);
    try expect(S.s[4] == 5);
}

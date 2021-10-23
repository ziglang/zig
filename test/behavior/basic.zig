const std = @import("std");
const builtin = @import("builtin");
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

const g1: i32 = 1233 + 1;
var g2: i32 = 0;

test "global variables" {
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
    try expect(mem.eql(u8, first4KeysOfHomeRow(), "aoeu"));
}

test "hex escape" {
    try expect(mem.eql(u8, "\x68\x65\x6c\x6c\x6f", "hello"));
}

test "multiline string" {
    const s1 =
        \\one
        \\two)
        \\three
    ;
    const s2 = "one\ntwo)\nthree";
    try expect(mem.eql(u8, s1, s2));
}

test "multiline string comments at start" {
    const s1 =
        //\\one
        \\two)
        \\three
    ;
    const s2 = "two)\nthree";
    try expect(mem.eql(u8, s1, s2));
}

test "multiline string comments at end" {
    const s1 =
        \\one
        \\two)
        //\\three
    ;
    const s2 = "one\ntwo)";
    try expect(mem.eql(u8, s1, s2));
}

test "multiline string comments in middle" {
    const s1 =
        \\one
        //\\two)
        \\three
    ;
    const s2 = "one\nthree";
    try expect(mem.eql(u8, s1, s2));
}

test "multiline string comments at multiple places" {
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

test "call result of if else expression" {
    try expect(mem.eql(u8, f2(true), "a"));
    try expect(mem.eql(u8, f2(false), "b"));
}
fn f2(x: bool) []const u8 {
    return (if (x) fA else fB)();
}
fn fA() []const u8 {
    return "a";
}
fn fB() []const u8 {
    return "b";
}

test "string concatenation" {
    try expect(mem.eql(u8, "OK" ++ " IT " ++ "WORKED", "OK IT WORKED"));
}

test "array mult operator" {
    try expect(mem.eql(u8, "ab" ** 5, "ababababab"));
}

test "memcpy and memset intrinsics" {
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

const OpaqueA = opaque {};
const OpaqueB = opaque {};

test "opaque types" {
    try expect(*OpaqueA != *OpaqueB);
    if (!builtin.zig_is_stage2) {
        try expect(mem.eql(u8, @typeName(OpaqueA), "OpaqueA"));
        try expect(mem.eql(u8, @typeName(OpaqueB), "OpaqueB"));
    }
}

test "variable is allowed to be a pointer to an opaque type" {
    var x: i32 = 1234;
    _ = hereIsAnOpaqueType(@ptrCast(*OpaqueA, &x));
}
fn hereIsAnOpaqueType(ptr: *OpaqueA) *OpaqueA {
    var a = ptr;
    return a;
}

const global_a: i32 = 1234;
const global_b: *const i32 = &global_a;
const global_c: *const f32 = @ptrCast(*const f32, global_b);
test "compile time global reinterpret" {
    const d = @ptrCast(*const i32, global_c);
    try expect(d.* == 1234);
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

test "take address of parameter" {
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

fn emptyFn() void {}

test "constant equal function pointers" {
    const alias = emptyFn;
    try expect(comptime x: {
        break :x emptyFn == alias;
    });
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

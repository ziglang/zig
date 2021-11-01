const std = @import("std");
const builtin = @import("builtin");
const mem = std.mem;
const expect = std.testing.expect;
const expectEqualStrings = std.testing.expectEqualStrings;

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

test "variable is allowed to be a pointer to an opaque type" {
    var x: i32 = 1234;
    _ = hereIsAnOpaqueType(@ptrCast(*OpaqueA, &x));
}
fn hereIsAnOpaqueType(ptr: *OpaqueA) *OpaqueA {
    var a = ptr;
    return a;
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

test "global constant is loaded with a runtime-known index" {
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

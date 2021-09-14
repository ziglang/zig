const std = @import("std");
const testing = std.testing;
const expect = testing.expect;
const expectEqual = testing.expectEqual;

test "generic struct" {
    var a1 = GenNode(i32){
        .value = 13,
        .next = null,
    };
    var b1 = GenNode(bool){
        .value = true,
        .next = null,
    };
    try expect(a1.value == 13);
    try expect(a1.value == a1.getVal());
    try expect(b1.getVal());
}
fn GenNode(comptime T: type) type {
    return struct {
        value: T,
        next: ?*GenNode(T),
        fn getVal(n: *const GenNode(T)) T {
            return n.value;
        }
    };
}

test "const decls in struct" {
    try expect(GenericDataThing(3).count_plus_one == 4);
}
fn GenericDataThing(comptime count: isize) type {
    return struct {
        const count_plus_one = count + 1;
    };
}

test "use generic param in generic param" {
    try expect(aGenericFn(i32, 3, 4) == 7);
}
fn aGenericFn(comptime T: type, comptime a: T, b: T) T {
    return a + b;
}

test "generic fn with implicit cast" {
    try expect(getFirstByte(u8, &[_]u8{13}) == 13);
    try expect(getFirstByte(u16, &[_]u16{
        0,
        13,
    }) == 0);
}
fn getByte(ptr: ?*const u8) u8 {
    return ptr.?.*;
}
fn getFirstByte(comptime T: type, mem: []const T) u8 {
    return getByte(@ptrCast(*const u8, &mem[0]));
}

const foos = [_]fn (anytype) bool{
    foo1,
    foo2,
};

fn foo1(arg: anytype) bool {
    return arg;
}
fn foo2(arg: anytype) bool {
    return !arg;
}

test "array of generic fns" {
    try expect(foos[0](true));
    try expect(!foos[1](true));
}

test "generic fn keeps non-generic parameter types" {
    const A = 128;

    const S = struct {
        fn f(comptime T: type, s: []T) !void {
            try expect(A != @typeInfo(@TypeOf(s)).Pointer.alignment);
        }
    };

    // The compiler monomorphizes `S.f` for `T=u8` on its first use, check that
    // `x` type not affect `s` parameter type.
    var x: [16]u8 align(A) = undefined;
    try S.f(u8, &x);
}

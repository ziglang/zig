const std = @import("std");
const builtin = @import("builtin");
const testing = std.testing;
const expect = testing.expect;
const expectEqual = testing.expectEqual;

test "one param, explicit comptime" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;

    var x: usize = 0;
    x += checkSize(i32);
    x += checkSize(bool);
    x += checkSize(bool);
    try expect(x == 6);
}

fn checkSize(comptime T: type) usize {
    return @sizeOf(T);
}

test "simple generic fn" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;

    try expect(max(i32, 3, -1) == 3);
    try expect(max(u8, 1, 100) == 100);
    if (builtin.zig_backend == .stage1) {
        // TODO: stage2 is incorrectly emitting the following:
        // error: cast of value 1.23e-01 to type 'f32' loses information
        try expect(max(f32, 0.123, 0.456) == 0.456);
    }
    try expect(add(2, 3) == 5);
}

fn max(comptime T: type, a: T, b: T) T {
    return if (a > b) a else b;
}

fn add(comptime a: i32, b: i32) i32 {
    return (comptime a) + b;
}

const the_max = max(u32, 1234, 5678);
test "compile time generic eval" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;

    try expect(the_max == 5678);
}

fn gimmeTheBigOne(a: u32, b: u32) u32 {
    return max(u32, a, b);
}

fn shouldCallSameInstance(a: u32, b: u32) u32 {
    return max(u32, a, b);
}

fn sameButWithFloats(a: f64, b: f64) f64 {
    return max(f64, a, b);
}

test "fn with comptime args" {
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;

    try expect(gimmeTheBigOne(1234, 5678) == 5678);
    try expect(shouldCallSameInstance(34, 12) == 34);
    try expect(sameButWithFloats(0.43, 0.49) == 0.49);
}

test "anytype params" {
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;

    try expect(max_i32(12, 34) == 34);
    try expect(max_f64(1.2, 3.4) == 3.4);
    comptime {
        try expect(max_i32(12, 34) == 34);
        try expect(max_f64(1.2, 3.4) == 3.4);
    }
}

fn max_anytype(a: anytype, b: anytype) @TypeOf(a, b) {
    return if (a > b) a else b;
}

fn max_i32(a: i32, b: i32) i32 {
    return max_anytype(a, b);
}

fn max_f64(a: f64, b: f64) f64 {
    return max_anytype(a, b);
}

test "type constructed by comptime function call" {
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;

    var l: SimpleList(10) = undefined;
    l.array[0] = 10;
    l.array[1] = 11;
    l.array[2] = 12;
    const ptr = @ptrCast([*]u8, &l.array);
    try expect(ptr[0] == 10);
    try expect(ptr[1] == 11);
    try expect(ptr[2] == 12);
}

fn SimpleList(comptime L: usize) type {
    var mutable_T = u8;
    const T = mutable_T;
    return struct {
        array: [L]T,
    };
}

test "function with return type type" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;

    var list: List(i32) = undefined;
    var list2: List(i32) = undefined;
    list.length = 10;
    list2.length = 10;
    try expect(list.prealloc_items.len == 8);
    try expect(list2.prealloc_items.len == 8);
}

pub fn List(comptime T: type) type {
    return SmallList(T, 8);
}

pub fn SmallList(comptime T: type, comptime STATIC_SIZE: usize) type {
    return struct {
        items: []T,
        length: usize,
        prealloc_items: [STATIC_SIZE]T,
    };
}

test "const decls in struct" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;

    try expect(GenericDataThing(3).count_plus_one == 4);
}
fn GenericDataThing(comptime count: isize) type {
    return struct {
        const count_plus_one = count + 1;
    };
}

test "use generic param in generic param" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;

    try expect(aGenericFn(i32, 3, 4) == 7);
}
fn aGenericFn(comptime T: type, comptime a: T, b: T) T {
    return a + b;
}

test "generic fn with implicit cast" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;

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

test "generic fn keeps non-generic parameter types" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;

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

test "array of generic fns" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest;

    try expect(foos[0](true));
    try expect(!foos[1](true));
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

test "generic struct" {
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
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

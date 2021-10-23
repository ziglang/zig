const std = @import("std");
const expect = std.testing.expect;
const builtin = @import("builtin");
const native_arch = builtin.target.cpu.arch;

fn derp() align(@sizeOf(usize) * 2) i32 {
    return 1234;
}
fn noop1() align(1) void {}
fn noop4() align(4) void {}

test "function alignment" {
    // function alignment is a compile error on wasm32/wasm64
    if (native_arch == .wasm32 or native_arch == .wasm64) return error.SkipZigTest;

    try expect(derp() == 1234);
    try expect(@TypeOf(noop1) == fn () align(1) void);
    try expect(@TypeOf(noop4) == fn () align(4) void);
    noop1();
    noop4();
}

var baz: packed struct {
    a: u32,
    b: u32,
} = undefined;

test "packed struct alignment" {
    try expect(@TypeOf(&baz.b) == *align(1) u32);
}

const blah: packed struct {
    a: u3,
    b: u3,
    c: u2,
} = undefined;

test "bit field alignment" {
    try expect(@TypeOf(&blah.b) == *align(1:3:1) const u3);
}

test "implicitly decreasing fn alignment" {
    // function alignment is a compile error on wasm32/wasm64
    if (native_arch == .wasm32 or native_arch == .wasm64) return error.SkipZigTest;

    try testImplicitlyDecreaseFnAlign(alignedSmall, 1234);
    try testImplicitlyDecreaseFnAlign(alignedBig, 5678);
}

fn testImplicitlyDecreaseFnAlign(ptr: fn () align(1) i32, answer: i32) !void {
    try expect(ptr() == answer);
}

fn alignedSmall() align(8) i32 {
    return 1234;
}
fn alignedBig() align(16) i32 {
    return 5678;
}

test "@alignCast functions" {
    // function alignment is a compile error on wasm32/wasm64
    if (native_arch == .wasm32 or native_arch == .wasm64) return error.SkipZigTest;
    if (native_arch == .thumb) return error.SkipZigTest;

    try expect(fnExpectsOnly1(simple4) == 0x19);
}
fn fnExpectsOnly1(ptr: fn () align(1) i32) i32 {
    return fnExpects4(@alignCast(4, ptr));
}
fn fnExpects4(ptr: fn () align(4) i32) i32 {
    return ptr();
}
fn simple4() align(4) i32 {
    return 0x19;
}

test "generic function with align param" {
    // function alignment is a compile error on wasm32/wasm64
    if (native_arch == .wasm32 or native_arch == .wasm64) return error.SkipZigTest;
    if (native_arch == .thumb) return error.SkipZigTest;

    try expect(whyWouldYouEverDoThis(1) == 0x1);
    try expect(whyWouldYouEverDoThis(4) == 0x1);
    try expect(whyWouldYouEverDoThis(8) == 0x1);
}

fn whyWouldYouEverDoThis(comptime align_bytes: u8) align(align_bytes) u8 {
    _ = align_bytes;
    return 0x1;
}

test "@ptrCast preserves alignment of bigger source" {
    var x: u32 align(16) = 1234;
    const ptr = @ptrCast(*u8, &x);
    try expect(@TypeOf(ptr) == *align(16) u8);
}

test "runtime known array index has best alignment possible" {
    // take full advantage of over-alignment
    var array align(4) = [_]u8{ 1, 2, 3, 4 };
    try expect(@TypeOf(&array[0]) == *align(4) u8);
    try expect(@TypeOf(&array[1]) == *u8);
    try expect(@TypeOf(&array[2]) == *align(2) u8);
    try expect(@TypeOf(&array[3]) == *u8);

    // because align is too small but we still figure out to use 2
    var bigger align(2) = [_]u64{ 1, 2, 3, 4 };
    try expect(@TypeOf(&bigger[0]) == *align(2) u64);
    try expect(@TypeOf(&bigger[1]) == *align(2) u64);
    try expect(@TypeOf(&bigger[2]) == *align(2) u64);
    try expect(@TypeOf(&bigger[3]) == *align(2) u64);

    // because pointer is align 2 and u32 align % 2 == 0 we can assume align 2
    var smaller align(2) = [_]u32{ 1, 2, 3, 4 };
    var runtime_zero: usize = 0;
    comptime try expect(@TypeOf(smaller[runtime_zero..]) == []align(2) u32);
    comptime try expect(@TypeOf(smaller[runtime_zero..].ptr) == [*]align(2) u32);
    try testIndex(smaller[runtime_zero..].ptr, 0, *align(2) u32);
    try testIndex(smaller[runtime_zero..].ptr, 1, *align(2) u32);
    try testIndex(smaller[runtime_zero..].ptr, 2, *align(2) u32);
    try testIndex(smaller[runtime_zero..].ptr, 3, *align(2) u32);

    // has to use ABI alignment because index known at runtime only
    try testIndex2(array[runtime_zero..].ptr, 0, *u8);
    try testIndex2(array[runtime_zero..].ptr, 1, *u8);
    try testIndex2(array[runtime_zero..].ptr, 2, *u8);
    try testIndex2(array[runtime_zero..].ptr, 3, *u8);
}
fn testIndex(smaller: [*]align(2) u32, index: usize, comptime T: type) !void {
    comptime try expect(@TypeOf(&smaller[index]) == T);
}
fn testIndex2(ptr: [*]align(4) u8, index: usize, comptime T: type) !void {
    comptime try expect(@TypeOf(&ptr[index]) == T);
}

test "alignstack" {
    try expect(fnWithAlignedStack() == 1234);
}

fn fnWithAlignedStack() i32 {
    @setAlignStack(256);
    return 1234;
}

test "alignment of function with c calling convention" {
    var runtime_nothing = nothing;
    const casted1 = @ptrCast(*const u8, runtime_nothing);
    const casted2 = @ptrCast(fn () callconv(.C) void, casted1);
    casted2();
}

fn nothing() callconv(.C) void {}

const DefaultAligned = struct {
    nevermind: u32,
    badguy: i128,
};

test "read 128-bit field from default aligned struct in stack memory" {
    var default_aligned = DefaultAligned{
        .nevermind = 1,
        .badguy = 12,
    };
    try expect((@ptrToInt(&default_aligned.badguy) % 16) == 0);
    try expect(12 == default_aligned.badguy);
}

var default_aligned_global = DefaultAligned{
    .nevermind = 1,
    .badguy = 12,
};

test "read 128-bit field from default aligned struct in global memory" {
    try expect((@ptrToInt(&default_aligned_global.badguy) % 16) == 0);
    try expect(12 == default_aligned_global.badguy);
}

test "struct field explicit alignment" {
    const S = struct {
        const Node = struct {
            next: *Node,
            massive_byte: u8 align(64),
        };
    };

    var node: S.Node = undefined;
    node.massive_byte = 100;
    try expect(node.massive_byte == 100);
    comptime try expect(@TypeOf(&node.massive_byte) == *align(64) u8);
    try expect(@ptrToInt(&node.massive_byte) % 64 == 0);
}

test "align(@alignOf(T)) T does not force resolution of T" {
    const S = struct {
        const A = struct {
            a: *align(@alignOf(A)) A,
        };
        fn doTheTest() void {
            suspend {
                resume @frame();
            }
            _ = bar(@Frame(doTheTest));
        }
        fn bar(comptime T: type) *align(@alignOf(T)) T {
            ok = true;
            return undefined;
        }

        var ok = false;
    };
    _ = async S.doTheTest();
    try expect(S.ok);
}

test "align(N) on functions" {
    // function alignment is a compile error on wasm32/wasm64
    if (native_arch == .wasm32 or native_arch == .wasm64) return error.SkipZigTest;
    if (native_arch == .thumb) return error.SkipZigTest;

    try expect((@ptrToInt(overaligned_fn) & (0x1000 - 1)) == 0);
}
fn overaligned_fn() align(0x1000) i32 {
    return 42;
}

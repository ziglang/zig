const std = @import("std");
const expect = std.testing.expect;
const builtin = @import("builtin");
const native_arch = builtin.target.cpu.arch;
const assert = std.debug.assert;

var foo: u8 align(4) = 100;

test "global variable alignment" {
    comptime assert(@typeInfo(@TypeOf(&foo)).Pointer.alignment == 4);
    comptime assert(@TypeOf(&foo) == *align(4) u8);
    {
        const slice = @as(*align(4) [1]u8, &foo)[0..];
        comptime assert(@TypeOf(slice) == *align(4) [1]u8);
    }
}

test "large alignment of local constant" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest; // flaky

    const x: f32 align(128) = 12.34;
    try std.testing.expect(@intFromPtr(&x) % 128 == 0);
}

test "slicing array of length 1 can not assume runtime index is always zero" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest; // flaky

    var runtime_index: usize = 1;
    _ = &runtime_index;
    const slice = @as(*align(4) [1]u8, &foo)[runtime_index..];
    try expect(@TypeOf(slice) == []u8);
    try expect(slice.len == 0);
    try expect(@as(u2, @truncate(@intFromPtr(slice.ptr) - 1)) == 0);
}

test "default alignment allows unspecified in type syntax" {
    try expect(*u32 == *align(@alignOf(u32)) u32);
}

test "implicitly decreasing pointer alignment" {
    const a: u32 align(4) = 3;
    const b: u32 align(8) = 4;
    try expect(addUnaligned(&a, &b) == 7);
}

fn addUnaligned(a: *align(1) const u32, b: *align(1) const u32) u32 {
    return a.* + b.*;
}

test "@alignCast pointers" {
    var x: u32 align(4) = 1;
    expectsOnly1(&x);
    try expect(x == 2);
}
fn expectsOnly1(x: *align(1) u32) void {
    expects4(@alignCast(x));
}
fn expects4(x: *align(4) u32) void {
    x.* += 1;
}

test "alignment of struct with pointer has same alignment as usize" {
    try expect(@alignOf(struct {
        a: i32,
        b: *i32,
    }) == @alignOf(usize));
}

test "alignment and size of structs with 128-bit fields" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const A = struct {
        x: u128,
    };
    const B = extern struct {
        x: u128,
        y: u8,
    };
    const expected = switch (builtin.cpu.arch) {
        .arm,
        .armeb,
        .thumb,
        .thumbeb,
        .hexagon,
        .mips,
        .mipsel,
        .powerpc,
        .powerpcle,
        .r600,
        .amdgcn,
        .riscv32,
        .sparc,
        .sparcel,
        .s390x,
        .lanai,
        .wasm32,
        .wasm64,
        => .{
            .a_align = 8,
            .a_size = 16,

            .b_align = 16,
            .b_size = 32,

            .u128_align = 8,
            .u128_size = 16,
            .u129_align = 8,
            .u129_size = 24,
        },

        .mips64,
        .mips64el,
        .powerpc64,
        .powerpc64le,
        .sparc64,
        => switch (builtin.object_format) {
            .c => .{
                .a_align = 16,
                .a_size = 16,

                .b_align = 16,
                .b_size = 32,

                .u128_align = 16,
                .u128_size = 16,
                .u129_align = 16,
                .u129_size = 32,
            },
            else => .{
                .a_align = 8,
                .a_size = 16,

                .b_align = 16,
                .b_size = 32,

                .u128_align = 8,
                .u128_size = 16,
                .u129_align = 8,
                .u129_size = 24,
            },
        },

        .x86_64 => switch (builtin.zig_backend) {
            .stage2_x86_64 => .{
                .a_align = 8,
                .a_size = 16,

                .b_align = 16,
                .b_size = 32,

                .u128_align = 8,
                .u128_size = 16,
                .u129_align = 8,
                .u129_size = 24,
            },
            else => .{
                .a_align = 16,
                .a_size = 16,

                .b_align = 16,
                .b_size = 32,

                .u128_align = 16,
                .u128_size = 16,
                .u129_align = 16,
                .u129_size = 32,
            },
        },

        .x86,
        .aarch64,
        .aarch64_be,
        .aarch64_32,
        .riscv64,
        .bpfel,
        .bpfeb,
        .nvptx,
        .nvptx64,
        => .{
            .a_align = 16,
            .a_size = 16,

            .b_align = 16,
            .b_size = 32,

            .u128_align = 16,
            .u128_size = 16,
            .u129_align = 16,
            .u129_size = 32,
        },

        else => return error.SkipZigTest,
    };
    const min_struct_align = if (builtin.zig_backend == .stage2_c) 16 else 0;
    comptime {
        assert(@alignOf(A) == @max(expected.a_align, min_struct_align));
        assert(@sizeOf(A) == expected.a_size);

        assert(@alignOf(B) == @max(expected.b_align, min_struct_align));
        assert(@sizeOf(B) == expected.b_size);

        assert(@alignOf(u128) == expected.u128_align);
        assert(@sizeOf(u128) == expected.u128_size);

        assert(@alignOf(u129) == expected.u129_align);
        assert(@sizeOf(u129) == expected.u129_size);
    }
}

test "alignstack" {
    try expect(fnWithAlignedStack() == 1234);
}

fn fnWithAlignedStack() i32 {
    @setAlignStack(256);
    return 1234;
}

test "implicitly decreasing slice alignment" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const a: u32 align(4) = 3;
    const b: u32 align(8) = 4;
    try expect(addUnalignedSlice(@as(*const [1]u32, &a)[0..], @as(*const [1]u32, &b)[0..]) == 7);
}
fn addUnalignedSlice(a: []align(1) const u32, b: []align(1) const u32) u32 {
    return a[0] + b[0];
}

test "specifying alignment allows pointer cast" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    try testBytesAlign(0x33);
}
fn testBytesAlign(b: u8) !void {
    var bytes align(4) = [_]u8{ b, b, b, b };
    const ptr = @as(*u32, @ptrCast(&bytes[0]));
    try expect(ptr.* == 0x33333333);
}

test "@alignCast slices" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    var array align(4) = [_]u32{ 1, 1 };
    const slice = array[0..];
    sliceExpectsOnly1(slice);
    try expect(slice[0] == 2);
}
fn sliceExpectsOnly1(slice: []align(1) u32) void {
    sliceExpects4(@alignCast(slice));
}
fn sliceExpects4(slice: []align(4) u32) void {
    slice[0] += 1;
}

test "return error union with 128-bit integer" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    try expect(3 == try give());
}
fn give() anyerror!u128 {
    return 3;
}

test "page aligned array on stack" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    if (builtin.cpu.arch == .aarch64 and builtin.os.tag == .windows) {
        // https://github.com/ziglang/zig/issues/13679
        return error.SkipZigTest;
    }

    // Large alignment value to make it hard to accidentally pass.
    var array align(0x1000) = [_]u8{ 1, 2, 3, 4, 5, 6, 7, 8 };
    var number1: u8 align(16) = 42;
    var number2: u8 align(16) = 43;

    try expect(@intFromPtr(&array[0]) & 0xFFF == 0);
    try expect(array[3] == 4);

    try expect(@as(u4, @truncate(@intFromPtr(&number1))) == 0);
    try expect(@as(u4, @truncate(@intFromPtr(&number2))) == 0);
    try expect(number1 == 42);
    try expect(number2 == 43);
}

test "function alignment" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    // function alignment is a compile error on wasm32/wasm64
    if (native_arch == .wasm32 or native_arch == .wasm64) return error.SkipZigTest;

    const S = struct {
        fn alignExpr() align(@sizeOf(usize) * 2) i32 {
            return 1234;
        }
        fn align1() align(1) void {}
        fn align4() align(4) void {}
    };

    try expect(S.alignExpr() == 1234);
    try expect(@TypeOf(S.alignExpr) == fn () i32);
    try expect(@TypeOf(&S.alignExpr) == *align(@sizeOf(usize) * 2) const fn () i32);

    S.align1();
    try expect(@TypeOf(S.align1) == fn () void);
    try expect(@TypeOf(&S.align1) == *align(1) const fn () void);

    S.align4();
    try expect(@TypeOf(S.align4) == fn () void);
    try expect(@TypeOf(&S.align4) == *align(4) const fn () void);
}

test "implicitly decreasing fn alignment" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    // function alignment is a compile error on wasm32/wasm64
    if (native_arch == .wasm32 or native_arch == .wasm64) return error.SkipZigTest;

    try testImplicitlyDecreaseFnAlign(alignedSmall, 1234);
    try testImplicitlyDecreaseFnAlign(alignedBig, 5678);
}

fn testImplicitlyDecreaseFnAlign(ptr: *align(1) const fn () i32, answer: i32) !void {
    try expect(ptr() == answer);
}

fn alignedSmall() align(8) i32 {
    return 1234;
}
fn alignedBig() align(16) i32 {
    return 5678;
}

test "@alignCast functions" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    // function alignment is a compile error on wasm32/wasm64
    if (native_arch == .wasm32 or native_arch == .wasm64) return error.SkipZigTest;
    if (native_arch == .thumb) return error.SkipZigTest;

    try expect(fnExpectsOnly1(simple4) == 0x19);
}
fn fnExpectsOnly1(ptr: *align(1) const fn () i32) i32 {
    return fnExpects4(@alignCast(ptr));
}
fn fnExpects4(ptr: *align(4) const fn () i32) i32 {
    return ptr();
}
fn simple4() align(4) i32 {
    return 0x19;
}

test "function align expression depends on generic parameter" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    // function alignment is a compile error on wasm32/wasm64
    if (native_arch == .wasm32 or native_arch == .wasm64) return error.SkipZigTest;
    if (native_arch == .thumb) return error.SkipZigTest;

    const S = struct {
        fn doTheTest() !void {
            try expect(foobar(1) == 2);
            try expect(foobar(4) == 5);
            try expect(foobar(8) == 9);
        }

        fn foobar(comptime align_bytes: u8) align(align_bytes) u8 {
            return align_bytes + 1;
        }
    };
    try S.doTheTest();
    try comptime S.doTheTest();
}

test "function callconv expression depends on generic parameter" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const S = struct {
        fn doTheTest() !void {
            try expect(foobar(.C, 1) == 2);
            try expect(foobar(.Unspecified, 2) == 3);
        }

        fn foobar(comptime cc: std.builtin.CallingConvention, arg: u8) callconv(cc) u8 {
            return arg + 1;
        }
    };
    try S.doTheTest();
    try comptime S.doTheTest();
}

test "runtime-known array index has best alignment possible" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    // take full advantage of over-alignment
    var array align(4) = [_]u8{ 1, 2, 3, 4 };
    comptime assert(@TypeOf(&array[0]) == *align(4) u8);
    comptime assert(@TypeOf(&array[1]) == *u8);
    comptime assert(@TypeOf(&array[2]) == *align(2) u8);
    comptime assert(@TypeOf(&array[3]) == *u8);

    // because align is too small but we still figure out to use 2
    var bigger align(2) = [_]u64{ 1, 2, 3, 4 };
    comptime assert(@TypeOf(&bigger[0]) == *align(2) u64);
    comptime assert(@TypeOf(&bigger[1]) == *align(2) u64);
    comptime assert(@TypeOf(&bigger[2]) == *align(2) u64);
    comptime assert(@TypeOf(&bigger[3]) == *align(2) u64);

    // because pointer is align 2 and u32 align % 2 == 0 we can assume align 2
    var smaller align(2) = [_]u32{ 1, 2, 3, 4 };
    var runtime_zero: usize = 0;
    _ = &runtime_zero;
    comptime assert(@TypeOf(smaller[runtime_zero..]) == []align(2) u32);
    comptime assert(@TypeOf(smaller[runtime_zero..].ptr) == [*]align(2) u32);
    try testIndex(smaller[runtime_zero..].ptr, 0, *align(2) u32);
    try testIndex(smaller[runtime_zero..].ptr, 1, *align(2) u32);
    try testIndex(smaller[runtime_zero..].ptr, 2, *align(2) u32);
    try testIndex(smaller[runtime_zero..].ptr, 3, *align(2) u32);

    // has to use ABI alignment because index known at runtime only
    try testIndex2(&array, 0, *u8);
    try testIndex2(&array, 1, *u8);
    try testIndex2(&array, 2, *u8);
    try testIndex2(&array, 3, *u8);
}
fn testIndex(smaller: [*]align(2) u32, index: usize, comptime T: type) !void {
    comptime assert(@TypeOf(&smaller[index]) == T);
}
fn testIndex2(ptr: [*]align(4) u8, index: usize, comptime T: type) !void {
    comptime assert(@TypeOf(&ptr[index]) == T);
}

test "alignment of function with c calling convention" {
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    const a = @alignOf(@TypeOf(nothing));

    var runtime_nothing = &nothing;
    _ = &runtime_nothing;
    const casted1: *align(a) const u8 = @ptrCast(runtime_nothing);
    const casted2: *const fn () callconv(.C) void = @ptrCast(casted1);
    casted2();
}

fn nothing() callconv(.C) void {}

const DefaultAligned = struct {
    nevermind: u32,
    badguy: i128,
};

test "read 128-bit field from default aligned struct in stack memory" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    var default_aligned = DefaultAligned{
        .nevermind = 1,
        .badguy = 12,
    };
    _ = &default_aligned;
    try expect(12 == default_aligned.badguy);
}

var default_aligned_global = DefaultAligned{
    .nevermind = 1,
    .badguy = 12,
};

test "read 128-bit field from default aligned struct in global memory" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    try expect(12 == default_aligned_global.badguy);
}

test "struct field explicit alignment" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest; // flaky

    const S = struct {
        const Node = struct {
            next: *Node,
            massive_byte: u8 align(64),
        };
    };

    var node: S.Node = undefined;
    node.massive_byte = 100;
    try expect(node.massive_byte == 100);
    comptime assert(@TypeOf(&node.massive_byte) == *align(64) u8);
    try expect(@intFromPtr(&node.massive_byte) % 64 == 0);
}

test "align(@alignOf(T)) T does not force resolution of T" {
    if (true) return error.SkipZigTest; // TODO

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
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    if (builtin.zig_backend == .stage2_c) {
        // https://github.com/ziglang/zig/issues/16845
        return error.SkipZigTest;
    }

    if (builtin.zig_backend == .stage2_c and builtin.os.tag == .windows) {
        // This is not supported on MSVC.
        return error.SkipZigTest;
    }

    // function alignment is a compile error on wasm32/wasm64
    if (native_arch == .wasm32 or native_arch == .wasm64) return error.SkipZigTest;
    if (native_arch == .thumb) return error.SkipZigTest;

    try expect((@intFromPtr(&overaligned_fn) & (0x1000 - 1)) == 0);
}
fn overaligned_fn() align(0x1000) i32 {
    return 42;
}

test "comptime alloc alignment" {
    // TODO: it's impossible to test this in Zig today, since comptime vars do not have runtime addresses.
    if (true) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest; // flaky
    if (builtin.zig_backend == .stage2_llvm and builtin.target.cpu.arch == .x86) {
        // https://github.com/ziglang/zig/issues/18034
        return error.SkipZigTest;
    }

    comptime var bytes1 = [_]u8{0};
    _ = &bytes1;

    comptime var bytes2 align(256) = [_]u8{0};
    const bytes2_addr = @intFromPtr(&bytes2);
    try expect(bytes2_addr & 0xff == 0);
}

test "@alignCast null" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    var ptr: ?*anyopaque = null;
    _ = &ptr;
    const aligned: ?*anyopaque = @alignCast(ptr);
    try expect(aligned == null);
}

test "alignment of slice element" {
    const a: []align(1024) const u8 = undefined;
    try expect(@TypeOf(&a[0]) == *align(1024) const u8);
}

test "sub-aligned pointer field access" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest;

    // Originally reported at https://github.com/ziglang/zig/issues/14904

    const Header = extern struct {
        tag: u32,
        bytes_len: u32,
    };
    var buf: [9]u8 align(4) = .{ 1, 2, 3, 4, 5, 6, 7, 8, 9 };
    const ptr: *align(1) Header = @ptrCast(buf[1..][0..8]);
    const x = ptr.bytes_len;
    switch (builtin.cpu.arch.endian()) {
        .big => try expect(x == 0x06070809),
        .little => try expect(x == 0x09080706),
    }
}

test "alignment of zero-bit types is respected" {
    if (true) return error.SkipZigTest; // TODO

    const S = struct { arr: [0]usize = .{} };

    comptime assert(@alignOf(void) == 1);
    comptime assert(@alignOf(u0) == 1);
    comptime assert(@alignOf([0]usize) == @alignOf(usize));
    comptime assert(@alignOf(S) == @alignOf(usize));

    var s: S = .{};
    var v32: void align(32) = {};
    var x32: u0 align(32) = 0;
    var s32: S align(32) = .{};

    var zero: usize = 0;
    _ = &zero;

    try expect(@intFromPtr(&s) % @alignOf(usize) == 0);
    try expect(@intFromPtr(&s.arr) % @alignOf(usize) == 0);
    try expect(@intFromPtr(s.arr[zero..zero].ptr) % @alignOf(usize) == 0);
    try expect(@intFromPtr(&v32) % 32 == 0);
    try expect(@intFromPtr(&x32) % 32 == 0);
    try expect(@intFromPtr(&s32) % 32 == 0);
    try expect(@intFromPtr(&s32.arr) % 32 == 0);
    try expect(@intFromPtr(s32.arr[zero..zero].ptr) % 32 == 0);
}

test "zero-bit fields in extern struct pad fields appropriately" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest;

    const S = extern struct {
        x: u8,
        a: [0]u16 = .{},
        y: u8,
    };

    // `a` should give `S` alignment 2, and pad the `arr` field.
    comptime assert(@alignOf(S) == 2);
    comptime assert(@sizeOf(S) == 4);
    comptime assert(@offsetOf(S, "x") == 0);
    comptime assert(@offsetOf(S, "a") == 2);
    comptime assert(@offsetOf(S, "y") == 2);

    var s: S = .{ .x = 100, .y = 200 };

    try expect(@intFromPtr(&s) % 2 == 0);
    try expect(@intFromPtr(&s.y) - @intFromPtr(&s.x) == 2);
    try expect(@intFromPtr(&s.y) == @intFromPtr(&s.a));
    try expect(@as(*S, @fieldParentPtr("a", &s.a)) == &s);
}

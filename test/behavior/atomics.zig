const std = @import("std");
const builtin = @import("builtin");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

test "cmpxchg" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO

    try testCmpxchg();
    comptime try testCmpxchg();
}

fn testCmpxchg() !void {
    var x: i32 = 1234;
    if (@cmpxchgWeak(i32, &x, 99, 5678, .SeqCst, .SeqCst)) |x1| {
        try expect(x1 == 1234);
    } else {
        @panic("cmpxchg should have failed");
    }

    while (@cmpxchgWeak(i32, &x, 1234, 5678, .SeqCst, .SeqCst)) |x1| {
        try expect(x1 == 1234);
    }
    try expect(x == 5678);

    try expect(@cmpxchgStrong(i32, &x, 5678, 42, .SeqCst, .SeqCst) == null);
    try expect(x == 42);
}

test "fence" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO

    var x: i32 = 1234;
    @fence(.SeqCst);
    x = 5678;
}

test "atomicrmw and atomicload" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO

    var data: u8 = 200;
    try testAtomicRmw(&data);
    try expect(data == 42);
    try testAtomicLoad(&data);
}

fn testAtomicRmw(ptr: *u8) !void {
    const prev_value = @atomicRmw(u8, ptr, .Xchg, 42, .SeqCst);
    try expect(prev_value == 200);
    comptime {
        var x: i32 = 1234;
        const y: i32 = 12345;
        try expect(@atomicLoad(i32, &x, .SeqCst) == 1234);
        try expect(@atomicLoad(i32, &y, .SeqCst) == 12345);
    }
}

fn testAtomicLoad(ptr: *u8) !void {
    const x = @atomicLoad(u8, ptr, .SeqCst);
    try expect(x == 42);
}

test "cmpxchg with ptr" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO

    var data1: i32 = 1234;
    var data2: i32 = 5678;
    var data3: i32 = 9101;
    var x: *i32 = &data1;
    if (@cmpxchgWeak(*i32, &x, &data2, &data3, .SeqCst, .SeqCst)) |x1| {
        try expect(x1 == &data1);
    } else {
        @panic("cmpxchg should have failed");
    }

    while (@cmpxchgWeak(*i32, &x, &data1, &data3, .SeqCst, .SeqCst)) |x1| {
        try expect(x1 == &data1);
    }
    try expect(x == &data3);

    try expect(@cmpxchgStrong(*i32, &x, &data3, &data2, .SeqCst, .SeqCst) == null);
    try expect(x == &data2);
}

test "cmpxchg with ignored result" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO

    var x: i32 = 1234;

    _ = @cmpxchgStrong(i32, &x, 1234, 5678, .Monotonic, .Monotonic);

    try expect(5678 == x);
}

test "128-bit cmpxchg" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO

    if (builtin.cpu.arch != .x86_64) return error.SkipZigTest;
    if (comptime !std.Target.x86.featureSetHas(builtin.cpu.features, .cx16)) return error.SkipZigTest;

    try test_u128_cmpxchg();
    comptime try test_u128_cmpxchg();
}

fn test_u128_cmpxchg() !void {
    var x: u128 align(16) = 1234;
    if (@cmpxchgWeak(u128, &x, 99, 5678, .SeqCst, .SeqCst)) |x1| {
        try expect(x1 == 1234);
    } else {
        @panic("cmpxchg should have failed");
    }

    while (@cmpxchgWeak(u128, &x, 1234, 5678, .SeqCst, .SeqCst)) |x1| {
        try expect(x1 == 1234);
    }
    try expect(x == 5678);

    try expect(@cmpxchgStrong(u128, &x, 5678, 42, .SeqCst, .SeqCst) == null);
    try expect(x == 42);
}

var a_global_variable = @as(u32, 1234);

test "cmpxchg on a global variable" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO

    if (builtin.zig_backend == .stage2_llvm and builtin.cpu.arch == .aarch64) {
        // https://github.com/ziglang/zig/issues/10627
        return error.SkipZigTest;
    }

    _ = @cmpxchgWeak(u32, &a_global_variable, 1234, 42, .Acquire, .Monotonic);
    try expect(a_global_variable == 42);
}

test "atomic load and rmw with enum" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO

    const Value = enum(u8) { a, b, c };
    var x = Value.a;

    try expect(@atomicLoad(Value, &x, .SeqCst) != .b);

    _ = @atomicRmw(Value, &x, .Xchg, .c, .SeqCst);
    try expect(@atomicLoad(Value, &x, .SeqCst) == .c);
    try expect(@atomicLoad(Value, &x, .SeqCst) != .a);
    try expect(@atomicLoad(Value, &x, .SeqCst) != .b);
}

test "atomic store" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO

    var x: u32 = 0;
    @atomicStore(u32, &x, 1, .SeqCst);
    try expect(@atomicLoad(u32, &x, .SeqCst) == 1);
    @atomicStore(u32, &x, 12345678, .SeqCst);
    try expect(@atomicLoad(u32, &x, .SeqCst) == 12345678);
}

test "atomic store comptime" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO

    comptime try testAtomicStore();
    try testAtomicStore();
}

fn testAtomicStore() !void {
    var x: u32 = 0;
    @atomicStore(u32, &x, 1, .SeqCst);
    try expect(@atomicLoad(u32, &x, .SeqCst) == 1);
    @atomicStore(u32, &x, 12345678, .SeqCst);
    try expect(@atomicLoad(u32, &x, .SeqCst) == 12345678);
}

test "atomicrmw with floats" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO

    if (builtin.zig_backend == .stage2_c) {
        // TODO: test.c:34929:7: error: address argument to atomic operation must be a pointer to integer or pointer ('zig_f32 *' (aka 'float *') invalid
        // when compiling with -std=c99 -pedantic
        return error.SkipZigTest;
    }

    if ((builtin.zig_backend == .stage2_llvm or builtin.zig_backend == .stage2_c) and
        builtin.cpu.arch == .aarch64)
    {
        // https://github.com/ziglang/zig/issues/10627
        return error.SkipZigTest;
    }
    try testAtomicRmwFloat();
    comptime try testAtomicRmwFloat();
}

fn testAtomicRmwFloat() !void {
    var x: f32 = 0;
    try expect(x == 0);
    _ = @atomicRmw(f32, &x, .Xchg, 1, .SeqCst);
    try expect(x == 1);
    _ = @atomicRmw(f32, &x, .Add, 5, .SeqCst);
    try expect(x == 6);
    _ = @atomicRmw(f32, &x, .Sub, 2, .SeqCst);
    try expect(x == 4);
}

test "atomicrmw with ints" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO

    if (builtin.zig_backend == .stage2_c and builtin.cpu.arch == .aarch64) {
        return error.SkipZigTest;
    }

    try testAtomicRmwInts();
    comptime try testAtomicRmwInts();
}

fn testAtomicRmwInts() !void {
    // TODO: Use the max atomic bit size for the target, maybe builtin?
    try testAtomicRmwInt(.unsigned, 8);

    if (builtin.cpu.arch == .x86_64) {
        try testAtomicRmwInt(.unsigned, 16);
        try testAtomicRmwInt(.unsigned, 32);
        try testAtomicRmwInt(.unsigned, 64);
    }
}

fn testAtomicRmwInt(comptime signedness: std.builtin.Signedness, comptime N: usize) !void {
    const int = std.meta.Int(signedness, N);

    var x: int = 1;
    var res = @atomicRmw(int, &x, .Xchg, 3, .SeqCst);
    try expect(x == 3 and res == 1);

    res = @atomicRmw(int, &x, .Add, 3, .SeqCst);
    var y: int = 3;
    try expect(res == y);
    y = y + 3;
    try expect(x == y);

    res = @atomicRmw(int, &x, .Sub, 1, .SeqCst);
    try expect(res == y);
    y = y - 1;
    try expect(x == y);

    res = @atomicRmw(int, &x, .And, 4, .SeqCst);
    try expect(res == y);
    y = y & 4;
    try expect(x == y);

    res = @atomicRmw(int, &x, .Nand, 4, .SeqCst);
    try expect(res == y);
    y = ~(y & 4);
    try expect(x == y);

    res = @atomicRmw(int, &x, .Or, 6, .SeqCst);
    try expect(res == y);
    y = y | 6;
    try expect(x == y);

    res = @atomicRmw(int, &x, .Xor, 2, .SeqCst);
    try expect(res == y);
    y = y ^ 2;
    try expect(x == y);

    res = @atomicRmw(int, &x, .Max, 1, .SeqCst);
    try expect(res == y);
    y = @max(y, 1);
    try expect(x == y);

    res = @atomicRmw(int, &x, .Min, 1, .SeqCst);
    try expect(res == y);
    y = @min(y, 1);
    try expect(x == y);
}

test "atomicrmw with 128-bit ints" {
    if (builtin.cpu.arch != .x86_64) {
        // TODO: Ideally this could use target.atomicPtrAlignment and check for IntTooBig
        return error.SkipZigTest;
    }

    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO

    // TODO "ld.lld: undefined symbol: __sync_lock_test_and_set_16" on -mcpu x86_64
    if (builtin.zig_backend == .stage2_llvm) return error.SkipZigTest;

    try testAtomicRmwInt128(.unsigned);
    comptime try testAtomicRmwInt128(.unsigned);
}

fn testAtomicRmwInt128(comptime signedness: std.builtin.Signedness) !void {
    const int = std.meta.Int(signedness, 128);

    const initial: int = 0xaaaaaaaa_bbbbbbbb_cccccccc_dddddddd;
    const replacement: int = 0x00000000_00000005_00000000_00000003;

    var x: int align(16) = initial;
    var res = @atomicRmw(int, &x, .Xchg, replacement, .SeqCst);
    try expect(x == replacement and res == initial);

    var operator: int = 0x00000001_00000000_20000000_00000000;
    res = @atomicRmw(int, &x, .Add, operator, .SeqCst);
    var y: int = replacement;
    try expect(res == y);
    y = y + operator;
    try expect(x == y);

    operator = 0x00000000_10000000_00000000_20000000;
    res = @atomicRmw(int, &x, .Sub, operator, .SeqCst);
    try expect(res == y);
    y = y - operator;
    try expect(x == y);

    operator = 0x12345678_87654321_12345678_87654321;
    res = @atomicRmw(int, &x, .And, operator, .SeqCst);
    try expect(res == y);
    y = y & operator;
    try expect(x == y);

    operator = 0x00000000_10000000_00000000_20000000;
    res = @atomicRmw(int, &x, .Nand, operator, .SeqCst);
    try expect(res == y);
    y = ~(y & operator);
    try expect(x == y);

    operator = 0x12340000_56780000_67890000_98760000;
    res = @atomicRmw(int, &x, .Or, operator, .SeqCst);
    try expect(res == y);
    y = y | operator;
    try expect(x == y);

    operator = 0x0a0b0c0d_0e0f0102_03040506_0708090a;
    res = @atomicRmw(int, &x, .Xor, operator, .SeqCst);
    try expect(res == y);
    y = y ^ operator;
    try expect(x == y);

    operator = 0x00000000_10000000_00000000_20000000;
    res = @atomicRmw(int, &x, .Max, operator, .SeqCst);
    try expect(res == y);
    y = @max(y, operator);
    try expect(x == y);

    res = @atomicRmw(int, &x, .Min, operator, .SeqCst);
    try expect(res == y);
    y = @min(y, operator);
    try expect(x == y);
}

test "atomics with different types" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO

    if (builtin.zig_backend == .stage2_c and builtin.cpu.arch == .aarch64) {
        return error.SkipZigTest;
    }

    try testAtomicsWithType(bool, true, false);

    try testAtomicsWithType(u1, 0, 1);
    try testAtomicsWithType(i4, 0, 1);
    try testAtomicsWithType(u5, 0, 1);
    try testAtomicsWithType(i15, 0, 1);
    try testAtomicsWithType(u24, 0, 1);

    try testAtomicsWithType(u0, 0, 0);
    try testAtomicsWithType(i0, 0, 0);
}

fn testAtomicsWithType(comptime T: type, a: T, b: T) !void {
    var x: T = b;
    @atomicStore(T, &x, a, .SeqCst);
    try expect(x == a);
    try expect(@atomicLoad(T, &x, .SeqCst) == a);
    try expect(@atomicRmw(T, &x, .Xchg, b, .SeqCst) == a);
    try expect(@cmpxchgStrong(T, &x, b, a, .SeqCst, .SeqCst) == null);
    if (@sizeOf(T) != 0)
        try expect(@cmpxchgStrong(T, &x, b, a, .SeqCst, .SeqCst).? == a);
}

test "return @atomicStore, using it as a void value" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO

    const S = struct {
        const A = struct {
            value: usize,

            pub fn store(self: *A, value: usize) void {
                return @atomicStore(usize, &self.value, value, .Unordered);
            }

            pub fn store2(self: *A, value: usize) void {
                return switch (value) {
                    else => @atomicStore(usize, &self.value, value, .Unordered),
                };
            }
        };

        fn doTheTest() !void {
            var x: A = .{ .value = 5 };
            x.store(10);
            try expect(x.value == 10);
            x.store(100);
            try expect(x.value == 100);
        }
    };
    try S.doTheTest();
    comptime try S.doTheTest();
}

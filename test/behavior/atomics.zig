const std = @import("std");
const builtin = @import("builtin");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

const supports_128_bit_atomics = switch (builtin.cpu.arch) {
    // TODO: Ideally this could be sync'd with the logic in Sema.
    .aarch64, .aarch64_be, .aarch64_32 => true,
    .x86_64 => std.Target.x86.featureSetHas(builtin.cpu.features, .cx16),
    else => false,
};

test "cmpxchg" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    try testCmpxchg();
    try comptime testCmpxchg();
}

fn testCmpxchg() !void {
    var x: i32 = 1234;
    if (@cmpxchgWeak(i32, &x, 99, 5678, .seq_cst, .seq_cst)) |x1| {
        try expect(x1 == 1234);
    } else {
        @panic("cmpxchg should have failed");
    }

    while (@cmpxchgWeak(i32, &x, 1234, 5678, .seq_cst, .seq_cst)) |x1| {
        try expect(x1 == 1234);
    }
    try expect(x == 5678);

    try expect(@cmpxchgStrong(i32, &x, 5678, 42, .seq_cst, .seq_cst) == null);
    try expect(x == 42);
}

test "fence" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    var x: i32 = 1234;
    @fence(.seq_cst);
    x = 5678;
}

test "atomicrmw and atomicload" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    var data: u8 = 200;
    try testAtomicRmw(&data);
    try expect(data == 42);
    try testAtomicLoad(&data);
}

fn testAtomicRmw(ptr: *u8) !void {
    const prev_value = @atomicRmw(u8, ptr, .Xchg, 42, .seq_cst);
    try expect(prev_value == 200);
    comptime {
        var x: i32 = 1234;
        const y: i32 = 12345;
        try expect(@atomicLoad(i32, &x, .seq_cst) == 1234);
        try expect(@atomicLoad(i32, &y, .seq_cst) == 12345);
    }
}

fn testAtomicLoad(ptr: *u8) !void {
    const x = @atomicLoad(u8, ptr, .seq_cst);
    try expect(x == 42);
}

test "cmpxchg with ptr" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    var data1: i32 = 1234;
    var data2: i32 = 5678;
    var data3: i32 = 9101;
    var x: *i32 = &data1;
    if (@cmpxchgWeak(*i32, &x, &data2, &data3, .seq_cst, .seq_cst)) |x1| {
        try expect(x1 == &data1);
    } else {
        @panic("cmpxchg should have failed");
    }

    while (@cmpxchgWeak(*i32, &x, &data1, &data3, .seq_cst, .seq_cst)) |x1| {
        try expect(x1 == &data1);
    }
    try expect(x == &data3);

    try expect(@cmpxchgStrong(*i32, &x, &data3, &data2, .seq_cst, .seq_cst) == null);
    try expect(x == &data2);
}

test "cmpxchg with ignored result" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    var x: i32 = 1234;

    _ = @cmpxchgStrong(i32, &x, 1234, 5678, .monotonic, .monotonic);

    try expect(5678 == x);
}

test "128-bit cmpxchg" {
    if (!supports_128_bit_atomics) return error.SkipZigTest;

    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO

    try test_u128_cmpxchg();
    try comptime test_u128_cmpxchg();
}

fn test_u128_cmpxchg() !void {
    var x: u128 align(16) = 1234;
    if (@cmpxchgWeak(u128, &x, 99, 5678, .seq_cst, .seq_cst)) |x1| {
        try expect(x1 == 1234);
    } else {
        @panic("cmpxchg should have failed");
    }

    while (@cmpxchgWeak(u128, &x, 1234, 5678, .seq_cst, .seq_cst)) |x1| {
        try expect(x1 == 1234);
    }
    try expect(x == 5678);

    try expect(@cmpxchgStrong(u128, &x, 5678, 42, .seq_cst, .seq_cst) == null);
    try expect(x == 42);
}

var a_global_variable = @as(u32, 1234);

test "cmpxchg on a global variable" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    if (builtin.zig_backend == .stage2_llvm and builtin.cpu.arch == .aarch64) {
        // https://github.com/ziglang/zig/issues/10627
        return error.SkipZigTest;
    }

    _ = @cmpxchgWeak(u32, &a_global_variable, 1234, 42, .acquire, .monotonic);
    try expect(a_global_variable == 42);
}

test "atomic load and rmw with enum" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    const Value = enum(u8) { a, b, c };
    var x = Value.a;

    try expect(@atomicLoad(Value, &x, .seq_cst) != .b);

    _ = @atomicRmw(Value, &x, .Xchg, .c, .seq_cst);
    try expect(@atomicLoad(Value, &x, .seq_cst) == .c);
    try expect(@atomicLoad(Value, &x, .seq_cst) != .a);
    try expect(@atomicLoad(Value, &x, .seq_cst) != .b);
}

test "atomic store" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    var x: u32 = 0;
    @atomicStore(u32, &x, 1, .seq_cst);
    try expect(@atomicLoad(u32, &x, .seq_cst) == 1);
    @atomicStore(u32, &x, 12345678, .seq_cst);
    try expect(@atomicLoad(u32, &x, .seq_cst) == 12345678);
}

test "atomic store comptime" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    try comptime testAtomicStore();
    try testAtomicStore();
}

fn testAtomicStore() !void {
    var x: u32 = 0;
    @atomicStore(u32, &x, 1, .seq_cst);
    try expect(@atomicLoad(u32, &x, .seq_cst) == 1);
    @atomicStore(u32, &x, 12345678, .seq_cst);
    try expect(@atomicLoad(u32, &x, .seq_cst) == 12345678);
}

test "atomicrmw with floats" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    if (builtin.zig_backend == .stage2_llvm and builtin.cpu.arch == .aarch64) {
        // https://github.com/ziglang/zig/issues/10627
        return error.SkipZigTest;
    }
    try testAtomicRmwFloat();
    try comptime testAtomicRmwFloat();
}

fn testAtomicRmwFloat() !void {
    var x: f32 = 0;
    try expect(x == 0);
    _ = @atomicRmw(f32, &x, .Xchg, 1, .seq_cst);
    try expect(x == 1);
    _ = @atomicRmw(f32, &x, .Add, 5, .seq_cst);
    try expect(x == 6);
    _ = @atomicRmw(f32, &x, .Sub, 2, .seq_cst);
    try expect(x == 4);
    _ = @atomicRmw(f32, &x, .Max, 13, .seq_cst);
    try expect(x == 13);
    _ = @atomicRmw(f32, &x, .Min, 42, .seq_cst);
    try expect(x == 13);
}

test "atomicrmw with ints" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    if (builtin.zig_backend == .stage2_llvm and builtin.cpu.arch.isMIPS()) {
        // https://github.com/ziglang/zig/issues/16846
        return error.SkipZigTest;
    }

    try testAtomicRmwInts();
    try comptime testAtomicRmwInts();
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
    var res = @atomicRmw(int, &x, .Xchg, 3, .seq_cst);
    try expect(x == 3 and res == 1);

    res = @atomicRmw(int, &x, .Add, 3, .seq_cst);
    var y: int = 3;
    try expect(res == y);
    y = y + 3;
    try expect(x == y);

    res = @atomicRmw(int, &x, .Sub, 1, .seq_cst);
    try expect(res == y);
    y = y - 1;
    try expect(x == y);

    res = @atomicRmw(int, &x, .And, 4, .seq_cst);
    try expect(res == y);
    y = y & 4;
    try expect(x == y);

    res = @atomicRmw(int, &x, .Nand, 4, .seq_cst);
    try expect(res == y);
    y = ~(y & 4);
    try expect(x == y);

    res = @atomicRmw(int, &x, .Or, 6, .seq_cst);
    try expect(res == y);
    y = y | 6;
    try expect(x == y);

    res = @atomicRmw(int, &x, .Xor, 2, .seq_cst);
    try expect(res == y);
    y = y ^ 2;
    try expect(x == y);

    res = @atomicRmw(int, &x, .Max, 1, .seq_cst);
    try expect(res == y);
    y = @max(y, 1);
    try expect(x == y);

    res = @atomicRmw(int, &x, .Min, 1, .seq_cst);
    try expect(res == y);
    y = @min(y, 1);
    try expect(x == y);
}

test "atomicrmw with 128-bit ints" {
    if (!supports_128_bit_atomics) return error.SkipZigTest;

    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO

    // TODO "ld.lld: undefined symbol: __sync_lock_test_and_set_16" on -mcpu x86_64
    if (builtin.cpu.arch == .x86_64 and builtin.zig_backend == .stage2_llvm) return error.SkipZigTest;

    try testAtomicRmwInt128(.signed);
    try testAtomicRmwInt128(.unsigned);
    try comptime testAtomicRmwInt128(.signed);
    try comptime testAtomicRmwInt128(.unsigned);
}

fn testAtomicRmwInt128(comptime signedness: std.builtin.Signedness) !void {
    const uint = std.meta.Int(.unsigned, 128);
    const int = std.meta.Int(signedness, 128);

    const initial: int = @as(int, @bitCast(@as(uint, 0xaaaaaaaa_bbbbbbbb_cccccccc_dddddddd)));
    const replacement: int = 0x00000000_00000005_00000000_00000003;

    var x: int align(16) = initial;
    var res = @atomicRmw(int, &x, .Xchg, replacement, .seq_cst);
    try expect(x == replacement and res == initial);

    var operator: int = 0x00000001_00000000_20000000_00000000;
    res = @atomicRmw(int, &x, .Add, operator, .seq_cst);
    var y: int = replacement;
    try expect(res == y);
    y = y + operator;
    try expect(x == y);

    operator = 0x00000000_10000000_00000000_20000000;
    res = @atomicRmw(int, &x, .Sub, operator, .seq_cst);
    try expect(res == y);
    y = y - operator;
    try expect(x == y);

    operator = 0x12345678_87654321_12345678_87654321;
    res = @atomicRmw(int, &x, .And, operator, .seq_cst);
    try expect(res == y);
    y = y & operator;
    try expect(x == y);

    operator = 0x00000000_10000000_00000000_20000000;
    res = @atomicRmw(int, &x, .Nand, operator, .seq_cst);
    try expect(res == y);
    y = ~(y & operator);
    try expect(x == y);

    operator = 0x12340000_56780000_67890000_98760000;
    res = @atomicRmw(int, &x, .Or, operator, .seq_cst);
    try expect(res == y);
    y = y | operator;
    try expect(x == y);

    operator = 0x0a0b0c0d_0e0f0102_03040506_0708090a;
    res = @atomicRmw(int, &x, .Xor, operator, .seq_cst);
    try expect(res == y);
    y = y ^ operator;
    try expect(x == y);

    operator = 0x00000000_10000000_00000000_20000000;
    res = @atomicRmw(int, &x, .Max, operator, .seq_cst);
    try expect(res == y);
    y = @max(y, operator);
    try expect(x == y);

    res = @atomicRmw(int, &x, .Min, operator, .seq_cst);
    try expect(res == y);
    y = @min(y, operator);
    try expect(x == y);
}

test "atomics with different types" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

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
    @atomicStore(T, &x, a, .seq_cst);
    try expect(x == a);
    try expect(@atomicLoad(T, &x, .seq_cst) == a);
    try expect(@atomicRmw(T, &x, .Xchg, b, .seq_cst) == a);
    try expect(@cmpxchgStrong(T, &x, b, a, .seq_cst, .seq_cst) == null);
    if (@sizeOf(T) != 0)
        try expect(@cmpxchgStrong(T, &x, b, a, .seq_cst, .seq_cst).? == a);
}

test "return @atomicStore, using it as a void value" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    const S = struct {
        const A = struct {
            value: usize,

            pub fn store(self: *A, value: usize) void {
                return @atomicStore(usize, &self.value, value, .unordered);
            }

            pub fn store2(self: *A, value: usize) void {
                return switch (value) {
                    else => @atomicStore(usize, &self.value, value, .unordered),
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
    try comptime S.doTheTest();
}

const std = @import("std");
const builtin = @import("builtin");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

test "cmpxchg" {
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
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
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO

    var x: i32 = 1234;
    @fence(.SeqCst);
    x = 5678;
}

test "atomicrmw and atomicload" {
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
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
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
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
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO

    var x: i32 = 1234;

    _ = @cmpxchgStrong(i32, &x, 1234, 5678, .Monotonic, .Monotonic);

    try expect(5678 == x);
}

test "128-bit cmpxchg" {
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO
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
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO

    if ((builtin.zig_backend == .stage1 or builtin.zig_backend == .stage2_llvm) and
        builtin.cpu.arch == .aarch64)
    {
        // https://github.com/ziglang/zig/issues/10627
        return error.SkipZigTest;
    }

    _ = @cmpxchgWeak(u32, &a_global_variable, 1234, 42, .Acquire, .Monotonic);
    try expect(a_global_variable == 42);
}

test "atomic load and rmw with enum" {
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
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
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
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
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
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
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO

    if ((builtin.zig_backend == .stage1 or builtin.zig_backend == .stage2_llvm) and
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
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO

    try testAtomicRmwInt();
    comptime try testAtomicRmwInt();
}

fn testAtomicRmwInt() !void {
    var x: u8 = 1;
    var res = @atomicRmw(u8, &x, .Xchg, 3, .SeqCst);
    try expect(x == 3 and res == 1);
    _ = @atomicRmw(u8, &x, .Add, 3, .SeqCst);
    try expect(x == 6);
    _ = @atomicRmw(u8, &x, .Sub, 1, .SeqCst);
    try expect(x == 5);
    _ = @atomicRmw(u8, &x, .And, 4, .SeqCst);
    try expect(x == 4);
    _ = @atomicRmw(u8, &x, .Nand, 4, .SeqCst);
    try expect(x == 0xfb);
    _ = @atomicRmw(u8, &x, .Or, 6, .SeqCst);
    try expect(x == 0xff);
    _ = @atomicRmw(u8, &x, .Xor, 2, .SeqCst);
    try expect(x == 0xfd);

    _ = @atomicRmw(u8, &x, .Max, 1, .SeqCst);
    try expect(x == 0xfd);
    _ = @atomicRmw(u8, &x, .Min, 1, .SeqCst);
    try expect(x == 1);
}

test "atomics with different types" {
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO

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
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
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

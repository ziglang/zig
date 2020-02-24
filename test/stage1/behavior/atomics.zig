const std = @import("std");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const builtin = @import("builtin");
const AtomicRmwOp = builtin.AtomicRmwOp;
const AtomicOrder = builtin.AtomicOrder;

test "cmpxchg" {
    var x: i32 = 1234;
    if (@cmpxchgWeak(i32, &x, 99, 5678, AtomicOrder.SeqCst, AtomicOrder.SeqCst)) |x1| {
        expect(x1 == 1234);
    } else {
        @panic("cmpxchg should have failed");
    }

    while (@cmpxchgWeak(i32, &x, 1234, 5678, AtomicOrder.SeqCst, AtomicOrder.SeqCst)) |x1| {
        expect(x1 == 1234);
    }
    expect(x == 5678);

    expect(@cmpxchgStrong(i32, &x, 5678, 42, AtomicOrder.SeqCst, AtomicOrder.SeqCst) == null);
    expect(x == 42);
}

test "fence" {
    var x: i32 = 1234;
    @fence(AtomicOrder.SeqCst);
    x = 5678;
}

test "atomicrmw and atomicload" {
    var data: u8 = 200;
    testAtomicRmw(&data);
    expect(data == 42);
    testAtomicLoad(&data);
}

fn testAtomicRmw(ptr: *u8) void {
    const prev_value = @atomicRmw(u8, ptr, AtomicRmwOp.Xchg, 42, AtomicOrder.SeqCst);
    expect(prev_value == 200);
    comptime {
        var x: i32 = 1234;
        const y: i32 = 12345;
        expect(@atomicLoad(i32, &x, AtomicOrder.SeqCst) == 1234);
        expect(@atomicLoad(i32, &y, AtomicOrder.SeqCst) == 12345);
    }
}

fn testAtomicLoad(ptr: *u8) void {
    const x = @atomicLoad(u8, ptr, AtomicOrder.SeqCst);
    expect(x == 42);
}

test "cmpxchg with ptr" {
    var data1: i32 = 1234;
    var data2: i32 = 5678;
    var data3: i32 = 9101;
    var x: *i32 = &data1;
    if (@cmpxchgWeak(*i32, &x, &data2, &data3, AtomicOrder.SeqCst, AtomicOrder.SeqCst)) |x1| {
        expect(x1 == &data1);
    } else {
        @panic("cmpxchg should have failed");
    }

    while (@cmpxchgWeak(*i32, &x, &data1, &data3, AtomicOrder.SeqCst, AtomicOrder.SeqCst)) |x1| {
        expect(x1 == &data1);
    }
    expect(x == &data3);

    expect(@cmpxchgStrong(*i32, &x, &data3, &data2, AtomicOrder.SeqCst, AtomicOrder.SeqCst) == null);
    expect(x == &data2);
}

// TODO this test is disabled until this issue is resolved:
// https://github.com/ziglang/zig/issues/2883
// otherwise cross compiling will result in:
// lld: error: undefined symbol: __sync_val_compare_and_swap_16
//test "128-bit cmpxchg" {
//    var x: u128 align(16) = 1234; // TODO: https://github.com/ziglang/zig/issues/2987
//    if (@cmpxchgWeak(u128, &x, 99, 5678, .SeqCst, .SeqCst)) |x1| {
//        expect(x1 == 1234);
//    } else {
//        @panic("cmpxchg should have failed");
//    }
//
//    while (@cmpxchgWeak(u128, &x, 1234, 5678, .SeqCst, .SeqCst)) |x1| {
//        expect(x1 == 1234);
//    }
//    expect(x == 5678);
//
//    expect(@cmpxchgStrong(u128, &x, 5678, 42, .SeqCst, .SeqCst) == null);
//    expect(x == 42);
//}

test "cmpxchg with ignored result" {
    var x: i32 = 1234;
    var ptr = &x;

    _ = @cmpxchgStrong(i32, &x, 1234, 5678, .Monotonic, .Monotonic);

    expectEqual(@as(i32, 5678), x);
}

var a_global_variable = @as(u32, 1234);

test "cmpxchg on a global variable" {
    _ = @cmpxchgWeak(u32, &a_global_variable, 1234, 42, .Acquire, .Monotonic);
    expectEqual(@as(u32, 42), a_global_variable);
}

test "atomic load and rmw with enum" {
    const Value = enum(u8) {
        a,
        b,
        c,
    };
    var x = Value.a;

    expect(@atomicLoad(Value, &x, .SeqCst) != .b);

    _ = @atomicRmw(Value, &x, .Xchg, .c, .SeqCst);
    expect(@atomicLoad(Value, &x, .SeqCst) == .c);
    expect(@atomicLoad(Value, &x, .SeqCst) != .a);
    expect(@atomicLoad(Value, &x, .SeqCst) != .b);
}

test "atomic store" {
    var x: u32 = 0;
    @atomicStore(u32, &x, 1, .SeqCst);
    expect(@atomicLoad(u32, &x, .SeqCst) == 1);
    @atomicStore(u32, &x, 12345678, .SeqCst);
    expect(@atomicLoad(u32, &x, .SeqCst) == 12345678);
}

test "atomic store comptime" {
    comptime testAtomicStore();
    testAtomicStore();
}

fn testAtomicStore() void {
    var x: u32 = 0;
    @atomicStore(u32, &x, 1, .SeqCst);
    expect(@atomicLoad(u32, &x, .SeqCst) == 1);
    @atomicStore(u32, &x, 12345678, .SeqCst);
    expect(@atomicLoad(u32, &x, .SeqCst) == 12345678);
}

test "atomicrmw with floats" {
    if (builtin.arch == .aarch64 or builtin.arch == .arm or builtin.arch == .riscv64)
        return error.SkipZigTest;
    testAtomicRmwFloat();
}

fn testAtomicRmwFloat() void {
    var x: f32 = 0;
    expect(x == 0);
    _ = @atomicRmw(f32, &x, .Xchg, 1, .SeqCst);
    expect(x == 1);
    _ = @atomicRmw(f32, &x, .Add, 5, .SeqCst);
    expect(x == 6);
    _ = @atomicRmw(f32, &x, .Sub, 2, .SeqCst);
    expect(x == 4);
}

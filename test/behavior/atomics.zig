const std = @import("std");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const builtin = @import("builtin");

test "cmpxchg" {
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
    var x: i32 = 1234;
    @fence(.SeqCst);
    x = 5678;
}

test "atomicrmw and atomicload" {
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
    var x: i32 = 1234;

    _ = @cmpxchgStrong(i32, &x, 1234, 5678, .Monotonic, .Monotonic);

    try expect(5678 == x);
}

test "128-bit cmpxchg" {
    try test_u128_cmpxchg();
    comptime try test_u128_cmpxchg();
}

fn test_u128_cmpxchg() !void {
    if (builtin.zig_is_stage2) {
        if (builtin.stage2_arch != .x86_64) return error.SkipZigTest;
        if (!builtin.stage2_x86_cx16) return error.SkipZigTest;
    } else {
        if (builtin.cpu.arch != .x86_64) return error.SkipZigTest;
        if (comptime !std.Target.x86.featureSetHas(builtin.cpu.features, .cx16)) return error.SkipZigTest;
    }

    var x: u128 = 1234;
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
    _ = @cmpxchgWeak(u32, &a_global_variable, 1234, 42, .Acquire, .Monotonic);
    try expect(a_global_variable == 42);
}

test "atomic load and rmw with enum" {
    const Value = enum(u8) { a, b, c };
    var x = Value.a;

    try expect(@atomicLoad(Value, &x, .SeqCst) != .b);

    _ = @atomicRmw(Value, &x, .Xchg, .c, .SeqCst);
    try expect(@atomicLoad(Value, &x, .SeqCst) == .c);
    try expect(@atomicLoad(Value, &x, .SeqCst) != .a);
    try expect(@atomicLoad(Value, &x, .SeqCst) != .b);
}

const builtin = @import("builtin");

const std = @import("std");
const Io = std.Io;
const testing = std.testing;
const assert = std.debug.assert;

test "concurrent vs main prevents deadlock via oversubscription" {
    var threaded: Io.Threaded = .init(std.testing.allocator);
    defer threaded.deinit();
    const io = threaded.io();

    threaded.cpu_count = 1;

    var queue: Io.Queue(u8) = .init(&.{});

    var putter = io.concurrent(put, .{ io, &queue }) catch |err| switch (err) {
        error.ConcurrencyUnavailable => {
            try testing.expect(builtin.single_threaded);
            return;
        },
    };
    defer putter.cancel(io);

    try testing.expectEqual(42, queue.getOneUncancelable(io));
}

fn put(io: Io, queue: *Io.Queue(u8)) void {
    queue.putOneUncancelable(io, 42);
}

fn get(io: Io, queue: *Io.Queue(u8)) void {
    assert(queue.getOneUncancelable(io) == 42);
}

test "concurrent vs concurrent prevents deadlock via oversubscription" {
    var threaded: Io.Threaded = .init(std.testing.allocator);
    defer threaded.deinit();
    const io = threaded.io();

    threaded.cpu_count = 1;

    var queue: Io.Queue(u8) = .init(&.{});

    var putter = io.concurrent(put, .{ io, &queue }) catch |err| switch (err) {
        error.ConcurrencyUnavailable => {
            try testing.expect(builtin.single_threaded);
            return;
        },
    };
    defer putter.cancel(io);

    var getter = try io.concurrent(get, .{ io, &queue });
    defer getter.cancel(io);

    getter.await(io);
    putter.await(io);
}

const ByteArray256 = struct { x: [32]u8 align(32) };
const ByteArray512 = struct { x: [64]u8 align(64) };

fn concatByteArrays(a: ByteArray256, b: ByteArray256) ByteArray512 {
    return .{ .x = a.x ++ b.x };
}

test "async/concurrent context and result alignment" {
    var buffer: [2048]u8 align(@alignOf(ByteArray512)) = undefined;
    var fba: std.heap.FixedBufferAllocator = .init(&buffer);

    var threaded: std.Io.Threaded = .init(fba.allocator());
    defer threaded.deinit();
    const io = threaded.io();

    const a: ByteArray256 = .{ .x = @splat(2) };
    const b: ByteArray256 = .{ .x = @splat(3) };
    const expected: ByteArray512 = .{ .x = @as([32]u8, @splat(2)) ++ @as([32]u8, @splat(3)) };

    {
        var future = io.async(concatByteArrays, .{ a, b });
        const result = future.await(io);
        try std.testing.expectEqualSlices(u8, &expected.x, &result.x);
    }
    {
        var future = io.concurrent(concatByteArrays, .{ a, b }) catch |err| switch (err) {
            error.ConcurrencyUnavailable => {
                try testing.expect(builtin.single_threaded);
                return;
            },
        };
        const result = future.await(io);
        try std.testing.expectEqualSlices(u8, &expected.x, &result.x);
    }
}

fn concatByteArraysResultPtr(a: ByteArray256, b: ByteArray256, result: *ByteArray512) void {
    result.* = .{ .x = a.x ++ b.x };
}

test "Group.async context alignment" {
    var buffer: [2048]u8 align(@alignOf(ByteArray512)) = undefined;
    var fba: std.heap.FixedBufferAllocator = .init(&buffer);

    var threaded: std.Io.Threaded = .init(fba.allocator());
    defer threaded.deinit();
    const io = threaded.io();

    const a: ByteArray256 = .{ .x = @splat(2) };
    const b: ByteArray256 = .{ .x = @splat(3) };
    const expected: ByteArray512 = .{ .x = @as([32]u8, @splat(2)) ++ @as([32]u8, @splat(3)) };

    var group: std.Io.Group = .init;
    var result: ByteArray512 = undefined;
    group.async(io, concatByteArraysResultPtr, .{ a, b, &result });
    group.wait(io);
    try std.testing.expectEqualSlices(u8, &expected.x, &result.x);
}

fn returnArray() [32]u8 {
    return @splat(5);
}

test "async with array return type" {
    var threaded: std.Io.Threaded = .init(std.testing.allocator);
    defer threaded.deinit();
    const io = threaded.io();

    var future = io.async(returnArray, .{});
    const result = future.await(io);
    try std.testing.expectEqualSlices(u8, &@as([32]u8, @splat(5)), &result);
}

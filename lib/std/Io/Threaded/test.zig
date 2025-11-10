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

fn paramWithExtraAlignment(param: Align64) void {
    assert(param.data == 3);
}

fn returnValueWithExtraAlignment() Align64 {
    return .{ .data = 5 };
}

const Align64 = struct {
    data: u8 align(64),
};

test "async closure where result or context has extra alignment" {
    // A fixed buffer allocator is used instead of `std.testing.allocator` to
    // not get memory that has better alignment than requested.
    var buffer: [1024]u8 align(64) = undefined;
    var fba: std.heap.FixedBufferAllocator = .init(buffer[1..]);

    var threaded: std.Io.Threaded = .init(fba.allocator());
    defer threaded.deinit();
    const io = threaded.io();

    {
        var future = io.async(paramWithExtraAlignment, .{.{ .data = 3 }});
        future.await(io);
    }

    {
        var future = io.async(returnValueWithExtraAlignment, .{});
        const result = future.await(io);
        try std.testing.expectEqual(5, result.data);
    }
}

test "group closure where context has extra alignment" {
    // A fixed buffer allocator is used instead of `std.testing.allocator` to
    // not get memory that has better alignment than requested.
    var buffer: [1024]u8 align(64) = undefined;
    var fba: std.heap.FixedBufferAllocator = .init(buffer[1..]);

    var threaded: std.Io.Threaded = .init(fba.allocator());
    defer threaded.deinit();
    const io = threaded.io();

    var group: std.Io.Group = .init;
    defer group.cancel(io);

    group.async(io, paramWithExtraAlignment, .{.{ .data = 3 }});
}

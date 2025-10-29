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

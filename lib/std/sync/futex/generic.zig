// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.

const std = @import("../../std.zig");
const atomic = @import("../atomic.zig");

pub fn Futex(comptime Event: type) type {
    const WaitLock = switch (@hasDecl(Event, "Lock") and Event.Lock != void) {
        true => Event.Lock,
        else => Lock(.{
            .Event = Event,
            .byte_swap = switch (@hasDecl(Event, "lock_hint")) {
                true => Event.lock_hint == .fast,
                else => false,
            },
        }),
    };

    const bucket_count = switch (@hasDecl(Event, "bucket_count")) {
        true => Event.bucket_count,
        else => std.meta.bitCount(usize) << 2,
    };

    const WaitBucket = struct {
        lock: WaitLock = .{},
        waiters: usize = 0,
        root: ?*WaitNode = null,

        var array = [_]WaitBucket{WaitBucket{}} ** bucket_count;

        /// Hash a address to a wait-bucket.
        /// This uses the same method as seen in Amanieu's port of WTF::ParkingLot:
        /// https://github.com/Amanieu/parking_lot/blob/master/core/src/parking_lot.rs
        fn from(address: usize) *WaitBucket {
            const seed = @truncate(usize, 0x9E3779B97F4A7C15);
            const max = std.meta.bitCount(usize);
            const bits = @ctz(usize, array.len);
            const index = (address *% seed) >> (max - bits);
            return &array[index];
        }
    };

    const WaitNode = struct {

    };

    return struct {
        pub fn now() u64 {
            return Event.nanotime();
        }

        pub fn wait(ptr: *const u32, expect: u32, deadline: ?u64) error{TimedOut}!void {
            @compileError("TODO: parking_lot.parkConditionally()");

            const address = @ptrToInt(ptr);
            const bucket = WaitBucket.from(address);

            _ = atomic.fetchAdd(&bucket.waiters, 1, .SeqCst);
            
        }

        pub fn notifyOne(ptr: *const u32) void {
            const address = @ptrToInt(ptr);
            const bucket = WaitBucket.from(address);

            if (atomic.load(&bucket.waiters, .SeqCst) == 0) {
                return;
            }

            @compileError("TODO: parking_lot.unparkOne()");
        }

        pub fn notifyAll(ptr: *const u32) void {
            const address = @ptrToInt(ptr);
            const bucket = WaitBucket.from(address);

            if (atomic.load(&bucket.waiters, .SeqCst) == 0) {
                return;
            }

            @compileError("TODO: parking_lot.unparkAll()");
        }
    };
}

fn Lock(comptime config: anytype) type {
    const Event = config.Event;
    const byte_swap = config.byte_swap;

    @compileError("TODO: parking_lot.WordLock");
}
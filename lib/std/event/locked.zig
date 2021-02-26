// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const std = @import("../std.zig");
const Lock = std.event.Lock;

/// Thread-safe async/await lock that protects one piece of data.
/// Functions which are waiting for the lock are suspended, and
/// are resumed when the lock is released, in order.
pub fn Locked(comptime T: type) type {
    return struct {
        lock: Lock,
        private_data: T,

        const Self = @This();

        pub const HeldLock = struct {
            value: *T,
            held: Lock.Held,

            pub fn release(self: HeldLock) void {
                self.held.release();
            }
        };

        pub fn init(data: T) Self {
            return Self{
                .lock = Lock.init(),
                .private_data = data,
            };
        }

        pub fn deinit(self: *Self) void {
            self.lock.deinit();
        }

        pub fn acquire(self: *Self) callconv(.Async) HeldLock {
            return HeldLock{
                // TODO guaranteed allocation elision
                .held = self.lock.acquire(),
                .value = &self.private_data,
            };
        }
    };
}

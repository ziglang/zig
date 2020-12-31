// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const std = @import("../std.zig");
const RwLock = std.event.RwLock;

/// Thread-safe async/await RW lock that protects one piece of data.
/// Functions which are waiting for the lock are suspended, and
/// are resumed when the lock is released, in order.
pub fn RwLocked(comptime T: type) type {
    return struct {
        lock: RwLock,
        locked_data: T,

        const Self = @This();

        pub const HeldReadLock = struct {
            value: *const T,
            held: RwLock.HeldRead,

            pub fn release(self: HeldReadLock) void {
                self.held.release();
            }
        };

        pub const HeldWriteLock = struct {
            value: *T,
            held: RwLock.HeldWrite,

            pub fn release(self: HeldWriteLock) void {
                self.held.release();
            }
        };

        pub fn init(data: T) Self {
            return Self{
                .lock = RwLock.init(),
                .locked_data = data,
            };
        }

        pub fn deinit(self: *Self) void {
            self.lock.deinit();
        }

        pub fn acquireRead(self: *Self) callconv(.Async) HeldReadLock {
            return HeldReadLock{
                .held = self.lock.acquireRead(),
                .value = &self.locked_data,
            };
        }

        pub fn acquireWrite(self: *Self) callconv(.Async) HeldWriteLock {
            return HeldWriteLock{
                .held = self.lock.acquireWrite(),
                .value = &self.locked_data,
            };
        }
    };
}

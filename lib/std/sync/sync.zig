// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.

const std = @import("../std.zig");
const root = @import("root");

pub const atomic = @import("./atomic.zig");

pub const core = struct {
    pub const ParkingLot = @import("./core/ParkingLot.zig").ParkingLot;
    pub const Mutex = @import("./core/Mutex.zig").Mutex;
    pub const Condvar = @import("./core/Condvar.zig").Condvar;
    pub const Semaphore = @import("./core/Semaphore.zig").Semaphore;
    pub const RwLock = @import("./core/RwLock.zig").RwLock;
    pub const ResetEvent = @import("./core/ResetEvent.zig").ResetEvent;
    pub const WaitGroup = @import("./core/WaitGroup.zig").WaitGroup;
};

pub const backend = struct {
    pub const spin = @import("./backend/spin.zig");
    pub const event = @import("./backend/event.zig");

    pub const os = if (std.builtin.os.tag == .windows)
        @import("./backend/windows.zig")
    else if (std.builtin.os.tag == .linux)
        @import("./backend/linux.zig")
    else if (std.Target.current.isDarwin())
        @import("./backend/darwin.zig")
    else if (std.builtin.link_libc)
        @import("./backend/posix.zig")
    else
        spin;
};

pub const primitives = struct {
    pub const spin = with(backend.spin, 1, 0);
    pub const os = with(backend.os, 64, 1 * std.time.ns_per_ms);
    pub const event = with(backend.event, 256, 1 * std.time.ns_per_ms);

    pub fn with(
        comptime Backend: type,
        comptime bucket_count: usize,
        comptime eventually_fair_after: u64,
    ) type {
        return struct {
            pub const parking_lot = core.ParkingLot(.{
                .Lock = Backend.Lock,
                .Event = Backend.Event,
                .bucket_count = bucket_count,
                .eventually_fair_after = eventually_fair_after,
            });

            pub const Mutex = core.Mutex(parking_lot);
            pub const Condvar = core.Condvar(parking_lot);
            pub const Semaphore = core.Semaphore(parking_lot);
            pub const RwLock = core.RwLock(parking_lot);
            pub const ResetEvent = core.ResetEvent(parking_lot);
            pub const WaitGroup = core.WaitGroup(parking_lot);
        };
    }
};

pub usingnamespace if (@hasDecl(root, "sync"))
    root.sync
else if (std.io.mode == .evented)
    primitives.event
else
    primitives.os;

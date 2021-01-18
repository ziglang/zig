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
    /// Synchronization primitives which implement blocking by spinning on atomic.spinLoopHint().
    pub const spin = with(.{
        .Lock = backend.spin.Lock,
        .Event = backend.spin.Event,
        .bucket_count = 1,
        .eventually_fair_after = std.math.maxInt(usize),
        .nanotime = struct {
            fn nanotime() u64 {
                return 0;
            }
        }.nanotime,
    });

    /// Synchronization primitives which implement blocking by calling into the operating system.
    pub const os = with(.{
        .Lock = backend.os.Lock,
        .Event = backend.os.Event,
        .bucket_count = 64,
        .eventually_fair_after = 1 * std.time.ns_per_ms, 
        .nanotime = std.time.nanoTime,
    });

    /// Synchronization primitives which implement blocking using the std.event.Loop
    pub const event = with(.{
        .Event = backend.event.Lock,
        .Event = backend.event.Event,
        .bucket_count = 256,
        .eventually_fair_after = 1 * std.time.ns_per_ms,
        .nanotime = std.time.nanoTime,
    });

    /// Create your own synchronization primitives using the ParkingLot configuration.
    /// See ParkingLot.zig for documentation on the config options.
    pub fn with(config: anytype) type {
        return struct {
            pub const parking_lot = core.ParkingLot(.{
                .Lock = config.Lock,
                .Event = config.Event,
                .bucket_count = switch (@hasDecl(config, "bucket_count")) {
                    true => @as(usize, config.bucket_count),
                    else => std.meta.bitCount(usize), // arbitrary
                },
                .eventually_fair_after = switch (@hasDecl(config, "eventually_fair_after")) {
                    true => @as(u64, config.eventually_fair_after),
                    else => 0,
                },
                .nanotime => switch (@hasDecl(config, "nanotime")) {
                    true => @as(fn() u64, config.nanotime),
                    else => struct {
                        fn nanotime() u64 {
                            return 0;
                        }
                    }.nanotime,
                },
            });

            pub const Mutex = core.Mutex(parking_lot);
            pub const Condvar = core.Condvar(parking_lot);
            pub const Semaphore = core.Semaphore(parking_lot);
            pub const RwLock = core.RwLock(parking_lot);
            pub const ResetEvent = core.ResetEvent(parking_lot);
            pub const WaitGroup = core.WaitGroup(parking_lot);
        };
    }

    /// Synchronization primitives made for single threaded uses cases which optimize to no-ops when possible
    pub const debug = struct {
        pub const ParkingLot = @import("./core/ParkingLot.zig").DebugParkingLot;
        pub const Mutex = @import("./core/Mutex.zig").DebugMutex;
        pub const Condvar = @import("./core/Mutex.zig").DebugCondvar;
        pub const Semaphore = @import("./core/Mutex.zig").DebugSemaphore;
        pub const RwLock = @import("./core/Mutex.zig").DebugRwLock;
        pub const ResetEvent = @import("./core/Mutex.zig").DebugResetEvent;
        pub const WaitGroup = @import("./core/Mutex.zig").DebugWaitGroup;
    };
};

pub usingnamespace if (@hasDecl(root, "sync"))
    root.sync
else if (std.builtin.single_threaded)
    primitives.debug
else if (std.io.mode == .evented)
    primitives.event
else
    primitives.os;

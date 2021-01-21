const std = @import("../std.zig");
const core = @import("./core/core.zig");
const backend = @import("./backend/backend.zig");

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
    .nanotime = std.time.now,
});

/// Synchronization primitives which implement blocking using the std.event.Loop
pub const event = with(.{
    .Event = backend.event.Lock,
    .Event = backend.event.Event,
    .bucket_count = 256,
    .eventually_fair_after = 1 * std.time.ns_per_ms,
    .nanotime = std.time.now,
});

/// Create your own synchronization primitives using the ParkingLot configuration.
/// See ParkingLot.zig for documentation on the config options.
pub fn with(config: anytype) type {
    return struct {
        fn hasConfigAttribute(comptime name: []const u8) bool {
            const Config = @TypeOf(config);
            return @hasDecl(Config, name) or @hasField(Config, name);
        }

        pub const parking_lot = core.ParkingLot(.{
            .Lock = config.Lock,
            .Event = config.Event,
            .bucket_count = switch (hasConfigAttribute("bucket_count")) {
                true => @as(usize, config.bucket_count),
                else => std.meta.bitCount(usize), // arbitrary
            },
            .eventually_fair_after = switch (hasConfigAttribute("eventually_fair_after")) {
                true => @as(u64, config.eventually_fair_after),
                else => 0,
            },
            .nanotime = switch (hasConfigAttribute("nanotime")) {
                true => @as(fn() u64, config.nanotime),
                else => struct {
                    fn nanotime() u64 {
                        return 0;
                    }
                }.nanotime,
            },
        });

        pub const Condvar = core.Condvar(parking_lot);
        pub const Lock = config.Lock;
        pub const Mutex = core.Mutex(parking_lot);
        pub const ResetEvent = core.ResetEvent(parking_lot);
        pub const RwLock = core.RwLock(parking_lot);
        pub const Semaphore = core.Semaphore(parking_lot);
        pub const WaitGroup = core.WaitGroup(parking_lot);

        pub fn Once(comptime initFn: anytype) type {
            return core.Once(initFn, parking_lot);
        }
    };
}

/// Synchronization primitives made for single threaded uses cases which optimize to no-ops when possible
pub const debug = struct {
    pub const Condvar = @import("./core/Condvar.zig").DebugCondvar;
    pub const Lock = @import("./core/Lock.zig").DebugLock;
    pub const Mutex = @import("./core/Mutex.zig").DebugMutex;
    pub const Once = @import("./core/Once.zig").DebugOnce;
    pub const parking_lot = @import("./core/ParkingLot.zig").DebugParkingLot;
    pub const ResetEvent = @import("./core/ResetEvent.zig").DebugResetEvent;
    pub const RwLock = @import("./core/RwLock.zig").DebugRwLock;
    pub const Semaphore = @import("./core/Semaphore.zig").DebugSemaphore;
    pub const WaitGroup = @import("./core/WaitGroup.zig").DebugWaitGroup;
};
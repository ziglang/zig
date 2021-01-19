pub const Condvar = @import("./Condvar.zig").Condvar;
pub const Lock = @import("./Lock.zig").Lock;
pub const Mutex = @import("./Mutex.zig").Mutex;
pub const Once = @import("./Once.zig").Once;
pub const ParkingLot = @import("./ParkingLot.zig").ParkingLot;
pub const ResetEvent = @import("./ResetEvent.zig").ResetEvent;
pub const RwLock = @import("./RwLock.zig").RwLock;
pub const Semaphore = @import("./Semaphore.zig").Semaphore;
pub const WaitGroup = @import("./WaitGroup.zig").WaitGroup;

test "std.sync" {
    _ = @import("./Condvar.zig");
    _ = @import("./Lock.zig");
    _ = @import("./Mutex.zig");
    _ = @import("./Once.zig");
    _ = @import("./ParkingLot.zig");
    _ = @import("./ResetEvent.zig");
    _ = @import("./RwLock.zig");
    _ = @import("./Semaphore.zig");
    _ = @import("./WaitGroup.zig");
}
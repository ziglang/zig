const std = @import("../index.zig");
const RwLock = std.event.RwLock;
const Loop = std.event.Loop;

/// Thread-safe async/await RW lock that protects one piece of data.
/// Does not make any syscalls - coroutines which are waiting for the lock are suspended, and
/// are resumed when the lock is released, in order.
pub fn RwLocked(comptime T: type) type {
    return struct {
        lock: RwLock,
        locked_data: T,

        const Self = this;

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

        pub fn init(loop: *Loop, data: T) Self {
            return Self{
                .lock = RwLock.init(loop),
                .locked_data = data,
            };
        }

        pub fn deinit(self: *Self) void {
            self.lock.deinit();
        }

        pub async fn acquireRead(self: *Self) HeldReadLock {
            return HeldReadLock{
                .held = await (async self.lock.acquireRead() catch unreachable),
                .value = &self.locked_data,
            };
        }

        pub async fn acquireWrite(self: *Self) HeldWriteLock {
            return HeldWriteLock{
                .held = await (async self.lock.acquireWrite() catch unreachable),
                .value = &self.locked_data,
            };
        }
    };
}

const std = @import("../index.zig");
const Lock = std.event.Lock;
const Loop = std.event.Loop;

/// Thread-safe async/await lock that protects one piece of data.
/// Does not make any syscalls - coroutines which are waiting for the lock are suspended, and
/// are resumed when the lock is released, in order.
pub fn Locked(comptime T: type) type {
    return struct {
        lock: Lock,
        private_data: T,

        const Self = this;

        pub const HeldLock = struct {
            value: *T,
            held: Lock.Held,

            pub fn release(self: HeldLock) void {
                self.held.release();
            }
        };

        pub fn init(loop: *Loop, data: T) Self {
            return Self{
                .lock = Lock.init(loop),
                .private_data = data,
            };
        }

        pub fn deinit(self: *Self) void {
            self.lock.deinit();
        }

        pub async fn acquire(self: *Self) HeldLock {
            return HeldLock{
            // TODO guaranteed allocation elision
                .held = await (async self.lock.acquire() catch unreachable),
                .value = &self.private_data,
            };
        }
    };
}

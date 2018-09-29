const builtin = @import("builtin");
const AtomicOrder = builtin.AtomicOrder;

/// Thread-safe, lock-free integer
pub fn Int(comptime T: type) type {
    return struct {
        unprotected_value: T,

        pub const Self = @This();

        pub fn init(init_val: T) Self {
            return Self{ .unprotected_value = init_val };
        }

        /// Returns previous value
        pub fn incr(self: *Self) T {
            return @atomicRmw(T, &self.unprotected_value, builtin.AtomicRmwOp.Add, 1, AtomicOrder.SeqCst);
        }

        /// Returns previous value
        pub fn decr(self: *Self) T {
            return @atomicRmw(T, &self.unprotected_value, builtin.AtomicRmwOp.Sub, 1, AtomicOrder.SeqCst);
        }

        pub fn get(self: *Self) T {
            return @atomicLoad(T, &self.unprotected_value, AtomicOrder.SeqCst);
        }

        pub fn xchg(self: *Self, new_value: T) T {
            return @atomicRmw(T, &self.unprotected_value, builtin.AtomicRmwOp.Xchg, new_value, AtomicOrder.SeqCst);
        }
    };
}

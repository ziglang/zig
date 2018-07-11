const builtin = @import("builtin");
const AtomicOrder = builtin.AtomicOrder;

/// Thread-safe, lock-free integer
pub fn Int(comptime T: type) type {
    return struct {
        value: T,

        pub const Self = this;

        pub fn init(init_val: T) Self {
            return Self{ .value = init_val };
        }

        pub fn next(self: *Self) T {
            return @atomicRmw(T, &self.value, builtin.AtomicRmwOp.Add, 1, AtomicOrder.SeqCst);
        }
    };
}

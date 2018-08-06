const std = @import("index.zig");
const builtin = @import("builtin");
const assert = std.debug.assert;
const AtomicRmwOp = builtin.AtomicRmwOp;
const AtomicOrder = builtin.AtomicOrder;

/// Thread-safe initialization of global data.
/// TODO use a mutex instead of a spinlock
pub fn lazyInit(comptime T: type) LazyInit(T) {
    return LazyInit(T){
        .data = undefined,
        .state = 0,
    };
}

fn LazyInit(comptime T: type) type {
    return struct {
        state: u8, // TODO make this an enum
        data: Data,

        const Self = this;

        // TODO this isn't working for void, investigate and then remove this special case
        const Data = if (@sizeOf(T) == 0) u8 else T;
        const Ptr = if (T == void) void else *T;

        /// Returns a usable pointer to the initialized data,
        /// or returns null, indicating that the caller should
        /// perform the initialization and then call resolve().
        pub fn get(self: *Self) ?Ptr {
            while (true) {
                var state = @cmpxchgWeak(u8, &self.state, 0, 1, AtomicOrder.SeqCst, AtomicOrder.SeqCst) orelse return null;
                switch (state) {
                    0 => continue,
                    1 => {
                        // TODO mutex instead of a spinlock
                        continue;
                    },
                    2 => {
                        if (@sizeOf(T) == 0) {
                            return T(undefined);
                        } else {
                            return &self.data;
                        }
                    },
                    else => unreachable,
                }
            }
        }

        pub fn resolve(self: *Self) void {
            const prev = @atomicRmw(u8, &self.state, AtomicRmwOp.Xchg, 2, AtomicOrder.SeqCst);
            assert(prev == 1); // resolve() called twice
        }
    };
}

var global_number = lazyInit(i32);

test "std.lazyInit" {
    if (global_number.get()) |_| @panic("bad") else {
        global_number.data = 1234;
        global_number.resolve();
    }
    if (global_number.get()) |x| {
        assert(x.* == 1234);
    } else {
        @panic("bad");
    }
    if (global_number.get()) |x| {
        assert(x.* == 1234);
    } else {
        @panic("bad");
    }
}

var global_void = lazyInit(void);

test "std.lazyInit(void)" {
    if (global_void.get()) |_| @panic("bad") else {
        global_void.resolve();
    }
    assert(global_void.get() != null);
    assert(global_void.get() != null);
}

const std = @import("std.zig");
const assert = std.debug.assert;
const testing = std.testing;

/// Thread-safe initialization of global data.
/// TODO use a mutex instead of a spinlock
pub fn lazyInit(comptime T: type) LazyInit(T) {
    return LazyInit(T){
        .data = undefined,
    };
}

fn LazyInit(comptime T: type) type {
    return struct {
        state: State = .NotResolved,
        data: Data,

        const State = enum(u8) {
            NotResolved,
            Resolving,
            Resolved,
        };

        const Self = @This();

        // TODO this isn't working for void, investigate and then remove this special case
        const Data = if (@sizeOf(T) == 0) u8 else T;
        const Ptr = if (T == void) void else *T;

        /// Returns a usable pointer to the initialized data,
        /// or returns null, indicating that the caller should
        /// perform the initialization and then call resolve().
        pub fn get(self: *Self) ?Ptr {
            while (true) {
                var state = @cmpxchgWeak(State, &self.state, .NotResolved, .Resolving, .SeqCst, .SeqCst) orelse return null;
                switch (state) {
                    .NotResolved => continue,
                    .Resolving => {
                        // TODO mutex instead of a spinlock
                        continue;
                    },
                    .Resolved => {
                        if (@sizeOf(T) == 0) {
                            return @as(T, undefined);
                        } else {
                            return &self.data;
                        }
                    },
                    else => unreachable,
                }
            }
        }

        pub fn resolve(self: *Self) void {
            const prev = @atomicRmw(State, &self.state, .Xchg, .Resolved, .SeqCst);
            assert(prev != .Resolved); // resolve() called twice
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
        testing.expect(x.* == 1234);
    } else {
        @panic("bad");
    }
    if (global_number.get()) |x| {
        testing.expect(x.* == 1234);
    } else {
        @panic("bad");
    }
}

var global_void = lazyInit(void);

test "std.lazyInit(void)" {
    if (global_void.get()) |_| @panic("bad") else {
        global_void.resolve();
    }
    testing.expect(global_void.get() != null);
    testing.expect(global_void.get() != null);
}

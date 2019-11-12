const std = @import("std.zig");
const builtin = @import("builtin");
const testing = std.testing;
const SpinLock = std.SpinLock;
const ThreadParker = std.ThreadParker;

/// Lock may be held only once. If the same thread
/// tries to acquire the same mutex twice, it deadlocks.
/// This type supports static initialization and is based off of Golang 1.13 runtime.lock_futex:
/// https://github.com/golang/go/blob/master/src/runtime/lock_futex.go
/// When an application is built in single threaded release mode, all the functions are
/// no-ops. In single threaded debug mode, there is deadlock detection.
pub const Mutex = if (builtin.single_threaded)
    struct {
        lock: @typeOf(lock_init),

        const lock_init = if (std.debug.runtime_safety) false else {};

        pub const Held = struct {
            mutex: *Mutex,

            pub fn release(self: Held) void {
                if (std.debug.runtime_safety) {
                    self.mutex.lock = false;
                }
            }
        };
        pub fn init() Mutex {
            return Mutex{ .lock = lock_init };
        }
        pub fn deinit(self: *Mutex) void {}

        pub fn acquire(self: *Mutex) Held {
            if (std.debug.runtime_safety and self.lock) {
                @panic("deadlock detected");
            }
            return Held{ .mutex = self };
        }
    }
else
    struct {
        state: State, // TODO: make this an enum
        parker: ThreadParker,

        const State = enum(u32) {
            Unlocked,
            Sleeping,
            Locked,
        };

        /// number of iterations to spin yielding the cpu
        const SPIN_CPU = 4;

        /// number of iterations to perform in the cpu yield loop
        const SPIN_CPU_COUNT = 30;

        /// number of iterations to spin yielding the thread
        const SPIN_THREAD = 1;

        pub fn init() Mutex {
            return Mutex{
                .state = .Unlocked,
                .parker = ThreadParker.init(),
            };
        }

        pub fn deinit(self: *Mutex) void {
            self.parker.deinit();
        }

        pub const Held = struct {
            mutex: *Mutex,

            pub fn release(self: Held) void {
                switch (@atomicRmw(State, &self.mutex.state, .Xchg, .Unlocked, .Release)) {
                    .Locked => {},
                    .Sleeping => self.mutex.parker.unpark(@ptrCast(*const u32,  &self.mutex.state)),
                    .Unlocked => unreachable, // unlocking an unlocked mutex
                    else => unreachable, // should never be anything else
                }
            }
        };

        pub fn acquire(self: *Mutex) Held {
            // Try and speculatively grab the lock.
            // If it fails, the state is either Locked or Sleeping
            // depending on if theres a thread stuck sleeping below.
            var state = @atomicRmw(State, &self.state, .Xchg, .Locked, .Acquire);
            if (state == .Unlocked)
                return Held{ .mutex = self };

            while (true) {
                // try and acquire the lock using cpu spinning on failure
                var spin: usize = 0;
                while (spin < SPIN_CPU) : (spin += 1) {
                    var value = @atomicLoad(State, &self.state, .Monotonic);
                    while (value == .Unlocked)
                        value = @cmpxchgWeak(State, &self.state, .Unlocked, state, .Acquire, .Monotonic) orelse return Held{ .mutex = self };
                    SpinLock.yield(SPIN_CPU_COUNT);
                }

                // try and acquire the lock using thread rescheduling on failure
                spin = 0;
                while (spin < SPIN_THREAD) : (spin += 1) {
                    var value = @atomicLoad(State, &self.state, .Monotonic);
                    while (value == .Unlocked)
                        value = @cmpxchgWeak(State, &self.state, .Unlocked, state, .Acquire, .Monotonic) orelse return Held{ .mutex = self };
                    std.os.sched_yield() catch std.time.sleep(1);
                }

                // failed to acquire the lock, go to sleep until woken up by `Held.release()`
                if (@atomicRmw(State, &self.state, .Xchg, .Sleeping, .Acquire) == .Unlocked)
                    return Held{ .mutex = self };
                state = .Sleeping;
                self.parker.park(@ptrCast(*const u32,  &self.state), @enumToInt(State.Sleeping));
            }
        }
    };

const TestContext = struct {
    mutex: *Mutex,
    data: i128,

    const incr_count = 10000;
};

test "std.Mutex" {
    var plenty_of_memory = try std.heap.direct_allocator.alloc(u8, 300 * 1024);
    defer std.heap.direct_allocator.free(plenty_of_memory);

    var fixed_buffer_allocator = std.heap.ThreadSafeFixedBufferAllocator.init(plenty_of_memory);
    var a = &fixed_buffer_allocator.allocator;

    var mutex = Mutex.init();
    defer mutex.deinit();

    var context = TestContext{
        .mutex = &mutex,
        .data = 0,
    };

    if (builtin.single_threaded) {
        worker(&context);
        testing.expect(context.data == TestContext.incr_count);
    } else {
        const thread_count = 10;
        var threads: [thread_count]*std.Thread = undefined;
        for (threads) |*t| {
            t.* = try std.Thread.spawn(&context, worker);
        }
        for (threads) |t|
            t.wait();

        testing.expect(context.data == thread_count * TestContext.incr_count);
    }
}

fn worker(ctx: *TestContext) void {
    var i: usize = 0;
    while (i != TestContext.incr_count) : (i += 1) {
        const held = ctx.mutex.acquire();
        defer held.release();

        ctx.data += 1;
    }
}

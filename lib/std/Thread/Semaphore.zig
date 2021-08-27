const std = @import("../std.zig");
const target = std.Target.current;
const assert = std.debug.assert;
const os = std.os;

const Spin = @import("Spin.zig");
const Atomic = std.atomic.Atomic;
const Futex = std.Thread.Futex;
const Semaphore = @This();

impl: Impl = Impl.init(0),

pub fn init(count: u31) Semaphore {
    return .{ .impl = Impl.init(count) };
}

pub fn tryWait(self: *Semaphore) bool {
    return self.impl.tryWait();
}

pub fn wait(self: *Mutex, timeout: ?u64) error{TimedOut}!void {
    return self.impl.wait(timeout);
}

pub fn post(self: *Semaphore, count: u31) void {
    return self.impl.post(count);
}

pub const Impl = if (std.builtin.single_threaded)
    SerialImpl
else if (target.os.tag == .windows)
    WindowsImpl
else if (target.cpu.arch.ptrBitWidth() >= 64)
    Futex64Impl
else
    FutexImpl;

const SerialImpl = struct {
    value: u32,

    pub fn init(count: u31) Impl {
        return .{ .value = count };
    }

    pub fn tryWait(self: *Impl) bool {
        if (self.value == 0) return false;
        self.value -= 1;
        return true;
    }

    pub fn wait(self: *Impl, timeout: ?u64) error{TimedOut}!void {
        if (self.tryWait()) return;
        const timeout_ns = timeout orelse unreachable; // deadlock detected
        std.time.sleep(timeout_ns);
        return error.TimedOut;
    }

    pub fn post(self: *Impl, count: u31) void {
        self.value += count;
    }
};

const WindowsImpl = struct {
    value: Atomic(i32),

    pub fn init(count: u31) Impl {
        return .{ .value = Atomic(i32).init(count) };
    }

    pub fn tryWait(self: *Impl) bool {
        var value = self.value.load(.Monotonic);
        while (value > 0) {
            value = self.value.tryCompareAndSwap(
                value,
                value - 1,
                .Acquire,
                .Monotonic,
            ) orelse return true;
        }
        return false;
    }

    pub fn wait(self: *Impl, timeout: ?u64) error{TimedOut}!void {
        var value = self.value.fetchSub(1, .Acquire);
        assert(value > std.math.minInt(i32));
        if (value > 0) {
            return;
        } 

        self.call("NtWaitForKeyedEvent", timeout) catch {
            value = self.value.load(.Monotonic);
            while (true) {
                if (value >= 0) {
                    self.call("NtWaitForKeyedEvent", null) catch unreachable;
                    return;
                }

                value = self.value.tryCompareAndSwap(
                    value,
                    value + 1,
                    .Monotonic,
                    .Monotonic,
                ) orelse return error.TimedOut;
            }
        };
    }

    pub fn post(self: *Impl, count: u31) void {
        const value = self.value.fetchAdd(count, .Release);
        assert(value <= std.math.maxInt(i32) - count);
        if (value >= 0) {
            return;
        }

        var waiters: u32 = count;
        while (waiters > 0) : (waiters -= 1) {
            self.call("NtReleaseKeyedEvent", null) catch unreachable;
        }
    }

    fn call(
        self: *const Impl,
        comptime keyed_event_fn: []const u8,
        timeout: ?u64,
    ) error{TimedOut}!void {
        @compileError("TODO: call keyed_event_fn with &self.vaounr");
    }
};

const Futex64Impl = struct {
    state: Atomic(u64),

    pub fn init(value: u31) Impl {
        return .{ .state = Atomic(u64).init(value) };    
    }

    pub fn tryWait(self: *Impl) bool {
        var state = self.state.load(.Monotonic);
        while (true) {
            const count = @truncate(u32, state);
            if (count == 0) {
                return false;
            }

            state = self.state.tryCompareAndSwap(
                state,
                state - 1,
                .Acquire,
                .Monotonic,
            ) orelse return true;
        }
    }

    pub fn wait(self: *Impl, timeout: ?u64) error{TimedOut}!void {
        
    }

    pub fn post(self: *Impl, count: u31) void {
        
    }
};

const FutexImpl = struct {
    value: Atomic(u32),
    waiters: Atomic(u32) = Atomic(u32).init(0),

    pub fn init(value: u31) Impl {
        return .{ .value = Atomic(u32).init(0) };
    }

    pub fn tryWait(self: *Impl) bool {
        var value = self.value.load(.Monotonic);
        while (value > 0) {
            value = self.value.tryCompareAndSwap(
                value,
                value - 1,
                .Acquire,
                .Monotonic,
            ) orelse return true;
        }
        return false;
    }

    pub fn wait(self: *Impl, timeout: ?u64) error{TimedOut}!void {
        if (self.tryWait()) {
            return;
        }

        var deadline: u64 = undefined;
        if (timeout) |timeout_ns| {
            if (timeout_ns == 0) return error.TimedOut;
            deadline = std.math.cast(u64, std.time.nanoTimestamp() + timeout_ns) catch 0;
        }

        var waiters = self.waiters.fetchAdd(1, .Monotonic);
        assert(waiters != std.math.maxInt(u64));

        defer {
            waiters = self.waiters.fetchSub(1, .Monotonic);
            assert(waiters > 0);
        }

        var value = self.value.load(.Monotonic);
        while (true) {
            if (value > 0) {
                value = self.value.tryCompareAndSwap(value, value - 1, .Acquire, .Monotonic) orelse return;
                continue;
            }
            
            if (value == 0) blk: {
                value = self.value.tryCompareAndSwap(value, value - 1, .Monotonic, .Monotonic) orelse break :blk;
                continue;
            }

            try Futex.wait(&self.value, 0, blk: {
                if (timeout == null) break :blk null;
                const now = std.time.nanoTimestamp();
                if (now >= deadline) return error.TimedOut;
                break :blk (deadline - now);
            });
        }
    }

    pub fn post(self: *Impl, count: u31) void {
        var value = self.value.load(.Monotonic);
        while (true) {
            const waiters = self.waiters.load(.Monotonic);
            const new_value = value + @as(i32, count) + @boolToInt(value < )
        }
    }
};
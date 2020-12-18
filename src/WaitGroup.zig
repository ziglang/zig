const std = @import("std");
const WaitGroup = @This();

lock: std.Mutex = .{},
counter: usize = 0,
event: std.AutoResetEvent = .{},

pub fn start(self: *WaitGroup) void {
    const held = self.lock.acquire();
    defer held.release();

    self.counter += 1;
}

pub fn stop(self: *WaitGroup) void {
    const held = self.lock.acquire();
    defer held.release();

    self.counter -= 1;
    if (self.counter == 0)
        self.event.set();
}

pub fn wait(self: *WaitGroup) void {
    {
        const held = self.lock.acquire();
        defer held.release();

        if (self.counter == 0)
            return;
    }

    self.event.wait();
}

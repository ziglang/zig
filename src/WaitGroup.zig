const std = @import("std");
const WaitGroup = @This();

mutex: std.Thread.Mutex = .{},
counter: usize = 0,
event: std.Thread.ResetEvent,

pub fn init(self: *WaitGroup) !void {
    self.* = .{
        .mutex = .{},
        .counter = 0,
        .event = undefined,
    };
    try self.event.init();
}

pub fn deinit(self: *WaitGroup) void {
    self.event.deinit();
    self.* = undefined;
}

pub fn start(self: *WaitGroup) void {
    self.mutex.lock();
    defer self.mutex.unlock();

    self.counter += 1;
}

pub fn finish(self: *WaitGroup) void {
    self.mutex.lock();
    defer self.mutex.unlock();

    self.counter -= 1;

    if (self.counter == 0) {
        self.event.set();
    }
}

pub fn wait(self: *WaitGroup) void {
    while (true) {
        self.mutex.lock();

        if (self.counter == 0) {
            self.mutex.unlock();
            return;
        }

        self.mutex.unlock();
        self.event.wait();
    }
}

pub fn reset(self: *WaitGroup) void {
    self.event.reset();
}

const std = @import("../std.zig");
const target = std.Target.current;
const Spin = @This();

counter: usize = switch (target.os.tag) {
    .macos, .ios, .watchos, .tvos => switch (target.cpu.arch) {
        .i386, .x86_64 => 1000,
        else => 10,
    },
    .linux => switch (target.cpu.arch) {
        .i386, .x86_64 => 100,
        else => 10,
    },
    .windows => 100,
    else => 0,
},

pub fn yield(self: *Spin) bool {
    if (self.counter == 0) {
        return false;
    }

    self.counter -= 1;
    std.atomic.spinLoopHint();
    return true;
}

pub fn forceYield(self: *Spin) void {
    if (!self.yield()) {
        std.os.sched_yield() catch {};
    }
}

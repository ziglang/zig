const std = @import("../std.zig");
const target = std.Target.current;
const SpinWait = @This();

// Spin for a longer period of time on x86 since throughput is more important there.
// Still spin a little bit for AARCH64 machines given they're also becoming throughput
// oriented while stil favoring power efficiency.
// Finally, don't spin for other platforms with the assumption that scalability
// is more important and throughput gains are unknown.
count: u8 = switch (target.cpu.arch) {
    .i386, .x86_64 => 100,
    .aarch64 => 10,
    else => 0,
},

/// Tries to spin for a bounded amount of time.
/// Returns true if the caller can invoke yield() again.
/// Returns false if the caller should stop spinning and actually block.
pub fn yield(self: *Spin) bool {
    if (self.count == 0) return false;
    self.count -= 1;
    std.atomic.spinLoopHint();
    return true;
}

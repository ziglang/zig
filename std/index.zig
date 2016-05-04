pub const Rand = @import("rand.zig").Rand;
pub const io = @import("io.zig");
pub const os = @import("os.zig");
pub const math = @import("math.zig");
pub const str = @import("str.zig");
pub const net = @import("net.zig");

pub fn assert(b: bool) {
    if (!b) unreachable{}
}


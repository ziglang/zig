pub const Rand = @import("rand.zig").Rand;
pub const io = @import("io.zig");
pub const os = @import("os.zig");
pub const math = @import("math.zig");
pub const str = @import("str.zig");
pub const cstr = @import("cstr.zig");
pub const net = @import("net.zig");
pub const list = @import("list.zig");
pub const hash_map = @import("hash_map.zig");
pub const mem = @import("mem.zig");
pub const linux = switch(@compile_var("os")) {
    linux => @import("linux.zig"),
    else => null_import,
};

pub fn assert(b: bool) {
    if (!b) unreachable{}
}

const null_import = @import("empty.zig");

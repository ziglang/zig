pub const rand = @import("rand.zig");
pub const io = @import("io.zig");
pub const os = @import("os.zig");
pub const math = @import("math.zig");
pub const str = @import("str.zig");
pub const cstr = @import("cstr.zig");
pub const net = @import("net.zig");
pub const list = @import("list.zig");
pub const hash_map = @import("hash_map.zig");
pub const mem = @import("mem.zig");
pub const debug = @import("debug.zig");
pub const linux = switch(@compileVar("os")) {
    linux => @import("linux.zig"),
    else => null_import,
};
pub const darwin = switch(@compileVar("os")) {
    darwin => @import("darwin.zig"),
    else => null_import,
};
const null_import = @import("empty.zig");

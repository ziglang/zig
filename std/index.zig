pub const cstr = @import("cstr.zig");
pub const debug = @import("debug.zig");
pub const fmt = @import("fmt.zig");
pub const hash_map = @import("hash_map.zig");
pub const io = @import("io.zig");
pub const list = @import("list.zig");
pub const math = @import("math.zig");
pub const mem = @import("mem.zig");
pub const net = @import("net.zig");
pub const os = @import("os.zig");
pub const rand = @import("rand.zig");
pub const sort = @import("sort.zig");
pub const linux = switch(@compileVar("os")) {
    Os.linux => @import("linux.zig"),
    else => empty_import,
};
pub const darwin = switch(@compileVar("os")) {
    Os.darwin => @import("darwin.zig"),
    else => empty_import,
};
pub const empty_import = @import("empty.zig");

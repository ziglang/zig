pub const base64 = @import("base64.zig");
pub const buffer = @import("buffer.zig");
pub const build = @import("build.zig");
pub const c = @import("c/index.zig");
pub const cstr = @import("cstr.zig");
pub const debug = @import("debug.zig");
pub const empty_import = @import("empty.zig");
pub const fmt = @import("fmt.zig");
pub const hash_map = @import("hash_map.zig");
pub const io = @import("io.zig");
pub const linked_list = @import("linked_list.zig");
pub const list = @import("list.zig");
pub const math = @import("math.zig");
pub const mem = @import("mem.zig");
pub const net = @import("net.zig");
pub const os = @import("os/index.zig");
pub const rand = @import("rand.zig");
pub const sort = @import("sort.zig");
pub const target = @import("target.zig");

test "std" {
    // run tests from these
    _ = @import("base64.zig");
    _ = @import("buffer.zig");
    _ = @import("build.zig");
    _ = @import("c/index.zig");
    _ = @import("cstr.zig");
    _ = @import("debug.zig");
    _ = @import("fmt.zig");
    _ = @import("hash_map.zig");
    _ = @import("io.zig");
    _ = @import("linked_list.zig");
    _ = @import("list.zig");
    _ = @import("math.zig");
    _ = @import("mem.zig");
    _ = @import("net.zig");
    _ = @import("os/index.zig");
    _ = @import("rand.zig");
    _ = @import("sort.zig");
    _ = @import("target.zig");
}

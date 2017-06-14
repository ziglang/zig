pub const ArrayList = @import("array_list.zig").ArrayList;
pub const BufMap = @import("buf_map.zig").BufMap;
pub const BufSet = @import("buf_set.zig").BufSet;
pub const Buffer = @import("buffer.zig").Buffer;
pub const HashMap = @import("hash_map.zig").HashMap;
pub const LinkedList = @import("linked_list.zig").LinkedList;

pub const base64 = @import("base64.zig");
pub const build = @import("build.zig");
pub const c = @import("c/index.zig");
pub const cstr = @import("cstr.zig");
pub const debug = @import("debug.zig");
pub const dwarf = @import("dwarf.zig");
pub const elf = @import("elf.zig");
pub const empty_import = @import("empty.zig");
pub const endian = @import("endian.zig");
pub const fmt = @import("fmt.zig");
pub const io = @import("io.zig");
pub const math = @import("math.zig");
pub const mem = @import("mem.zig");
pub const net = @import("net.zig");
pub const os = @import("os/index.zig");
pub const rand = @import("rand.zig");
pub const sort = @import("sort.zig");

test "std" {
    // run tests from these
    _ = @import("array_list.zig").ArrayList;
    _ = @import("buf_map.zig").BufMap;
    _ = @import("buf_set.zig").BufSet;
    _ = @import("buffer.zig").Buffer;
    _ = @import("hash_map.zig").HashMap;
    _ = @import("linked_list.zig").LinkedList;

    _ = @import("base64.zig");
    _ = @import("build.zig");
    _ = @import("c/index.zig");
    _ = @import("cstr.zig");
    _ = @import("debug.zig");
    _ = @import("dwarf.zig");
    _ = @import("elf.zig");
    _ = @import("empty.zig");
    _ = @import("endian.zig");
    _ = @import("fmt.zig");
    _ = @import("io.zig");
    _ = @import("math.zig");
    _ = @import("mem.zig");
    _ = @import("net.zig");
    _ = @import("os/index.zig");
    _ = @import("rand.zig");
    _ = @import("sort.zig");
}

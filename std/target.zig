const mem = @import("mem.zig");
const builtin = @import("builtin");

pub const linking_libc = linkingLibrary("c");

pub fn linkingLibrary(lib_name: []const u8) -> bool {
    // TODO shouldn't need this if
    if (builtin.link_libs.len != 0) {
        for (builtin.link_libs) |link_lib| {
            if (mem.eql(u8, link_lib, lib_name)) {
                return true;
            }
        }
    }
    return false;
}

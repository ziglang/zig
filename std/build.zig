const mem = @import("mem.zig");

pub fn linkingLibrary(lib_name: []const u8) -> bool {
    // TODO shouldn't need this if
    if (@compileVar("link_libs").len != 0) {
        for (@compileVar("link_libs")) |link_lib| {
            if (mem.eql(u8, link_lib, lib_name)) {
                return true;
            }
        }
    }
    return false;
}

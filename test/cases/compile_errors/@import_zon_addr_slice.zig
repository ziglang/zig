pub fn main() void {
    const f: struct { value: []const i32 } = @import("zon/addr_slice.zon");
    _ = f;
}

// error
// imports=zon/addr_slice.zon
//
// addr_slice.zon:2:14: error: pointers are not available in ZON

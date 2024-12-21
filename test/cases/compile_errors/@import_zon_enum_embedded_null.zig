const std = @import("std");
pub fn main() void {
    const E = enum { foo };
    const f: struct { E, E } = @import("zon/enum_embedded_null.zon");
    _ = f;
}

// error
// backend=stage2
// output_mode=Exe
// imports=zon/enum_embedded_null.zon
//
// enum_embedded_null.zon:2:6: error: identifier cannot contain null bytes

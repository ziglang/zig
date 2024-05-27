const std = @import("std");
pub fn main() void {
    const f = @import("zon/enum_embedded_null.zon");
    _ = f;
}

// error
// backend=stage2
// output_mode=Exe
// imports=zon/enum_embedded_null.zon
//
// foobarbaz

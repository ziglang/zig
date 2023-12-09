const std = @import("std");
pub fn main() void {
    const f = @import("zon/struct_dup_field.zon");
    _ = f;
}

// error
// backend=stage2
// output_mode=Exe
// imports=zon/struct_dup_field.zon
//
// struct_dup_field.zon:3:6: error: duplicate field

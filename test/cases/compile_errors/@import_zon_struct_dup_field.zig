const std = @import("std");
export fn entry() void {
    const f: struct { name: u8 } = @import("zon/struct_dup_field.zon");
    _ = f;
}

// error
// imports=zon/struct_dup_field.zon
//
// struct_dup_field.zon:2:6: error: duplicate struct field name
// struct_dup_field.zon:3:6: note: duplicate name here

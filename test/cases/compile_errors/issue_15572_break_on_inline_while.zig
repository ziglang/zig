const std = @import("std");

pub const DwarfSection = enum {
    eh_frame,
    eh_frame_hdr,
};

pub fn main() void {
    const section = inline for (@typeInfo(DwarfSection).@"enum".fields) |section| {
        if (std.mem.eql(u8, section.name, "eh_frame")) break section;
    };

    _ = section;
}

// error
// backend=stage2
// target=native
//
// :9:28: error: incompatible types: 'builtin.Type.EnumField' and 'void'

usingnamespace @import("b.zig");

pub const a_text = "OK\n";

pub fn ok() bool {
    return @import("std").mem.eql(u8, @This().b_text, "OK\n");
}

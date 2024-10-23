const std = @import("std");
const expect = std.testing.expect;

pub const a linksection("sec_a") = 0;
pub const b linksection("sec_b") = 0;
pub const c addrspace("space_c") = 0;
pub const d addrspace("space_d") = 0;

test {
    const decls = @typeInfo(@This()).@"struct".decls;
    try expect(decls.len == 4);
}

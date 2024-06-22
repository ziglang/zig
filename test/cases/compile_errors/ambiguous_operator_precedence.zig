const std = @import("std");

test {
    var x: u16 = 0xFF00;
    const y: u8 = 0xFF;
    x = x | y & 0x0F;
    try std.testing.expect(x == 0xFF0F);
}

// error
// backend=stage2
// target=native
//
// :6:15: error: ambiguous operator precedence; use parentheses to disambiguate

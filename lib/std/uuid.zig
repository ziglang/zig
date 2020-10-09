// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2020 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const rand = @import("std.zig").rand;

const Self = @This();
id: u128,

/// Creates a brand new UUID v4 object given a random number generator.
pub fn newv4(gen: *rand.Random) Self {
    //This sets the 4 bits at the 48 bit to 0
    const flip: u128 = 0b1111 << 48;

    //We then set the 4 bits at 48 to 0x4 (0b0100)
    return Self{ .id = ((gen.int(u128) & ~flip) | (0x4 << 48)) };
}

/// Creates a string from the ID.
/// Format: xxxxxxxx-xxxx-4xxx-xxxx-xxxxxxxxxxxx
pub fn format(value: Self, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
    var buf = [_]u8{0} ** 36;

    var chars = "0123456789ABCDEF";
    if (fmt.len == 0 or mem.eql(u8, fmt, "x")) {
        // use lower-case hexadecimal digits for printing
        chars = "0123456789abcdef";
    } else if (mem.eql(u8, fmt, "X")) {
        // use upper-case hexadecimal digits
        chars = "0123456789ABCDEF";
    } else {
        @compileError("invalid format string '" ++ fmt ++ "'");
    }

    //Pre-set known values
    buf[8] = '-';
    buf[13] = '-';
    buf[14] = '4';
    buf[18] = '-';
    buf[23] = '-';

    //Generate the string
    var i: usize = 0;
    var shift: u7 = 0;
    while (i < 36) : (i += 1) {
        //Skip pre-set values
        if (i != 8 and i != 13 and i != 18 and i != 23) {
            const selector = @truncate(u4, self.id >> shift);
            shift += 4;

            buf[i] = chars[@intCast(usize, selector)];
        }
    }

    try writer.writeAll(buf);
}

// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2020 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const std = @import("std.zig");

const Uuid = @This();
id: u128,

/// Creates a brand new UUID v4 object.
pub fn newv4() Uuid {
    // This sets the 4 bits at the 48 bit to 0
    const flip: u128 = 0b1111 << 48;

    // We then set the 4 bits at 48 to 0x4 (0b0100)
    return Uuid{ .id = (std.crypto.random.int(u128) & ~flip) | (0x4 << 48) };
}

/// Creates a string from the ID.
/// Format: xxxxxxxx-xxxx-4xxx-xxxx-xxxxxxxxxxxx
pub fn format(self: Uuid, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
    var buf = [_]u8{0} ** 36;

    const chars = if (fmt.len == 0 or comptime std.mem.eql(u8, fmt, "x"))
        // use lower-case hexadecimal digits for printing
        "0123456789abcdef"
    else if (comptime std.mem.eql(u8, fmt, "X"))
        // use upper-case hexadecimal digits
        "0123456789ABCDEF"
    else
        @compileError("invalid format string '" ++ fmt ++ "'");

    // Pre-set known values
    buf[8] = '-';
    buf[13] = '-';
    buf[18] = '-';
    buf[23] = '-';

    // Generate the string
    var i: usize = 0;
    var shift: u7 = 0;
    while (i < 36) : (i += 1) {
        // Skip pre-set values
        if (i != 8 and i != 13 and i != 18 and i != 23) {
            const selector = @truncate(u4, self.id >> shift);
            // Wrapping addition since 4*32=128 will overflow after
            // the last character
            shift +%= 4;

            buf[i] = chars[selector];
        }
    }

    try writer.writeAll(&buf);
}

test "uuid format" {
    var buf: [36]u8 = undefined;

    var uuid = newv4();
    std.testing.expect(uuid.id & (0b1111 << 48) == 0x4 << 48);

    // generated using newv4()
    uuid = .{ .id = 167152534942602288892154198807769749718 };
    std.testing.expectEqualStrings("6d897582-18ac-496f-abf1-d95604860cd7", try std.fmt.bufPrint(&buf, "{}", .{uuid}));
    std.testing.expectEqualStrings("6d897582-18ac-496f-abf1-d95604860cd7", try std.fmt.bufPrint(&buf, "{x}", .{uuid}));
    std.testing.expectEqualStrings("6D897582-18AC-496F-ABF1-D95604860CD7", try std.fmt.bufPrint(&buf, "{X}", .{uuid}));
}

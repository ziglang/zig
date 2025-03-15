//! Developed by ITU-U and ISO/IEC for naming objects. Used in DER.
//!
//! This implementation supports any number of `u32` arcs.

const Arc = u32;
const encoding_base = 128;

/// Returns encoded length.
pub fn encodeLen(dot_notation: []const u8) !usize {
    var split = std.mem.splitScalar(u8, dot_notation, '.');
    if (split.next() == null) return 0;
    if (split.next() == null) return 1;

    var res: usize = 1;
    while (split.next()) |s| {
        const parsed = try std.fmt.parseUnsigned(Arc, s, 10);
        const n_bytes = if (parsed == 0) 0 else std.math.log(Arc, encoding_base, parsed);

        res += n_bytes;
        res += 1;
    }

    return res;
}

pub const EncodeError = std.fmt.ParseIntError || error{
    MissingPrefix,
    BufferTooSmall,
};

pub fn encode(dot_notation: []const u8, buf: []u8) EncodeError![]const u8 {
    if (buf.len < try encodeLen(dot_notation)) return error.BufferTooSmall;

    var split = std.mem.splitScalar(u8, dot_notation, '.');
    const first_str = split.next() orelse return error.MissingPrefix;
    const second_str = split.next() orelse return error.MissingPrefix;

    const first = try std.fmt.parseInt(u8, first_str, 10);
    const second = try std.fmt.parseInt(u8, second_str, 10);

    buf[0] = first * 40 + second;

    var i: usize = 1;
    while (split.next()) |s| {
        var parsed = try std.fmt.parseUnsigned(Arc, s, 10);
        const n_bytes = if (parsed == 0) 0 else std.math.log(Arc, encoding_base, parsed);

        for (0..n_bytes) |j| {
            const place = std.math.pow(Arc, encoding_base, n_bytes - @as(Arc, @intCast(j)));
            const digit: u8 = @intCast(@divFloor(parsed, place));

            buf[i] = digit | 0x80;
            parsed -= digit * place;

            i += 1;
        }
        buf[i] = @intCast(parsed);
        i += 1;
    }

    return buf[0..i];
}

pub fn decode(encoded: []const u8, writer: anytype) @TypeOf(writer).Error!void {
    const first = @divTrunc(encoded[0], 40);
    const second = encoded[0] - first * 40;
    try writer.print("{d}.{d}", .{ first, second });

    var i: usize = 1;
    while (i != encoded.len) {
        const n_bytes: usize = brk: {
            var res: usize = 1;
            var j: usize = i;
            while (encoded[j] & 0x80 != 0) {
                res += 1;
                j += 1;
            }
            break :brk res;
        };

        var n: usize = 0;
        for (0..n_bytes) |j| {
            const place = std.math.pow(usize, encoding_base, n_bytes - j - 1);
            n += place * (encoded[i] & 0b01111111);
            i += 1;
        }
        try writer.print(".{d}", .{n});
    }
}

pub fn encodeComptime(comptime dot_notation: []const u8) [encodeLen(dot_notation) catch unreachable]u8 {
    @setEvalBranchQuota(10_000);
    var buf: [encodeLen(dot_notation) catch unreachable]u8 = undefined;
    _ = encode(dot_notation, &buf) catch unreachable;
    return buf;
}

const std = @import("std");

fn testOid(expected_encoded: []const u8, expected_dot_notation: []const u8) !void {
    var buf: [256]u8 = undefined;
    const encoded = try encode(expected_dot_notation, &buf);
    try std.testing.expectEqualSlices(u8, expected_encoded, encoded);

    var stream = std.io.fixedBufferStream(&buf);
    try decode(expected_encoded, stream.writer());
    try std.testing.expectEqualStrings(expected_dot_notation, stream.getWritten());
}

test "encode and decode" {
    // https://learn.microsoft.com/en-us/windows/win32/seccertenroll/about-object-identifier
    try testOid(
        &[_]u8{ 0x2b, 0x06, 0x01, 0x04, 0x01, 0x82, 0x37, 0x15, 0x14 },
        "1.3.6.1.4.1.311.21.20",
    );
    // https://luca.ntop.org/Teaching/Appunti/asn1.html
    try testOid(&[_]u8{ 0x2a, 0x86, 0x48, 0x86, 0xf7, 0x0d }, "1.2.840.113549");
    // https://www.sysadmins.lv/blog-en/how-to-encode-object-identifier-to-an-asn1-der-encoded-string.aspx
    try testOid(&[_]u8{ 0x2a, 0x86, 0x8d, 0x20 }, "1.2.100000");
    try testOid(
        &[_]u8{ 0x2a, 0x86, 0x48, 0x86, 0xf7, 0x0d, 0x01, 0x01, 0x0b },
        "1.2.840.113549.1.1.11",
    );
    try testOid(&[_]u8{ 0x2b, 0x65, 0x70 }, "1.3.101.112");
}

test encodeComptime {
    try std.testing.expectEqual(
        [_]u8{ 0x2b, 0x06, 0x01, 0x04, 0x01, 0x82, 0x37, 0x15, 0x14 },
        encodeComptime("1.3.6.1.4.1.311.21.20"),
    );
}

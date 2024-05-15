//! Distinguised Encoding Rules as defined in X.690 and X.691.
//!
//! Subset of Basic Encoding Rules (BER) which eliminates flexibility in
//! an effort to acheive normality. Used in PKI.
const std = @import("std");
const asn1 = @import("../asn1.zig");

pub const Decoder = @import("der/Decoder.zig");
pub const Encoder = @import("der/Encoder.zig");

pub fn decode(comptime T: type, encoded: []const u8) !T {
    var decoder = Decoder{ .bytes = encoded };
    const res = try decoder.any(T);
    std.debug.assert(decoder.index == encoded.len);
    return res;
}

/// Caller owns returned memory.
pub fn encode(allocator: std.mem.Allocator, value: anytype) ![]u8 {
    var encoder = Encoder.init(allocator);
    defer encoder.deinit();
    try encoder.any(value);
    return try encoder.buffer.toOwnedSlice();
}

test {
    _ = Decoder;
    _ = Encoder;
}

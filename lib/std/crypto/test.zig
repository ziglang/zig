const std = @import("../std.zig");
const testing = std.testing;
const fmt = std.fmt;

// Hash using the specified hasher `H` asserting `expected == H(input)`.
pub fn assertEqualHash(
    comptime Hasher: type,
    expected_hex: *const [Hasher.digest_length * 2:0]u8,
    input: []const u8,
) !void {
    const digest = Hasher.hash(input);
    try assertEqual(expected_hex, &digest);
}

pub fn assertEqual(expected_hex: [:0]const u8, actual_bin_digest: []const u8) !void {
    var buffer: [200]u8 = undefined;
    const actual_hex = std.fmt.bufPrint(&buffer, "{x}", .{actual_bin_digest}) catch @panic("buffer too small");
    try testing.expectEqualStrings(expected_hex, actual_hex);
}

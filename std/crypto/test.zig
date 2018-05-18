const debug = @import("../debug/index.zig");
const mem = @import("../mem.zig");
const fmt = @import("../fmt/index.zig");

// Hash using the specified hasher `H` asserting `expected == H(input)`.
pub fn assertEqualHash(comptime Hasher: var, comptime expected: []const u8, input: []const u8) void {
    var h: [expected.len / 2]u8 = undefined;
    Hasher.hash(input, h[0..]);

    assertEqual(expected, h);
}

// Assert `expected` == `input` where `input` is a bytestring.
pub fn assertEqual(comptime expected: []const u8, input: []const u8) void {
    var expected_bytes: [expected.len / 2]u8 = undefined;
    for (expected_bytes) |*r, i| {
        r.* = fmt.parseInt(u8, expected[2 * i .. 2 * i + 2], 16) catch unreachable;
    }

    debug.assert(mem.eql(u8, expected_bytes, input));
}

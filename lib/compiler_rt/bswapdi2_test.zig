const bswap = @import("bswap.zig");
const testing = @import("std").testing;

fn test__bswapdi2(a: u64, expected: u64) !void {
    const result = bswap.__bswapdi2(a);
    try testing.expectEqual(expected, result);
}

test "bswapdi2" {
    try test__bswapdi2(0x0123456789abcdef, 0xefcdab8967452301); // 0..f
    try test__bswapdi2(0xefcdab8967452301, 0x0123456789abcdef);
    try test__bswapdi2(0x89abcdef01234567, 0x67452301efcdab89); // 8..f0..7
    try test__bswapdi2(0x67452301efcdab89, 0x89abcdef01234567);
    try test__bswapdi2(0xdeadbeefdeadbeef, 0xefbeaddeefbeadde); // deadbeefdeadbeef
    try test__bswapdi2(0xefbeaddeefbeadde, 0xdeadbeefdeadbeef);
    try test__bswapdi2(0xdeadfacedeadface, 0xcefaaddecefaadde); // deadfacedeadface
    try test__bswapdi2(0xcefaaddecefaadde, 0xdeadfacedeadface);
    try test__bswapdi2(0xaaaaaaaaaaaaaaaa, 0xaaaaaaaaaaaaaaaa); // uninitialized memory
    try test__bswapdi2(0x0000000000000000, 0x0000000000000000); // 0s
    try test__bswapdi2(0xffffffffffffffff, 0xffffffffffffffff); // fs
}

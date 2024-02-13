const bswap = @import("bswap.zig");
const testing = @import("std").testing;

fn test__bswapsi2(a: u32, expected: u32) !void {
    const result = bswap.__bswapsi2(a);
    try testing.expectEqual(expected, result);
}

test "bswapsi2" {
    try test__bswapsi2(0x01234567, 0x67452301); // 0..7
    try test__bswapsi2(0x67452301, 0x01234567);
    try test__bswapsi2(0x89abcdef, 0xefcdab89); // 8..f
    try test__bswapsi2(0xefcdab89, 0x89abcdef);
    try test__bswapsi2(0xdeadbeef, 0xefbeadde); // deadbeef
    try test__bswapsi2(0xefbeadde, 0xdeadbeef);
    try test__bswapsi2(0xdeadface, 0xcefaadde); // deadface
    try test__bswapsi2(0xcefaadde, 0xdeadface);
    try test__bswapsi2(0xaaaaaaaa, 0xaaaaaaaa); // uninitialized memory
    try test__bswapsi2(0x00000000, 0x00000000); // 0s
    try test__bswapsi2(0xffffffff, 0xffffffff); // fs
}

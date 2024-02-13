const bswap = @import("bswap.zig");
const testing = @import("std").testing;

fn test__bswapti2(a: u128, expected: u128) !void {
    const result = bswap.__bswapti2(a);
    try testing.expectEqual(expected, result);
}

test "bswapti2" {
    try test__bswapti2(0x0123456789abcdef0123456789abcdef, 0xefcdab8967452301efcdab8967452301); // 0..f
    try test__bswapti2(0xefcdab8967452301efcdab8967452301, 0x0123456789abcdef0123456789abcdef);
    try test__bswapti2(0x89abcdef0123456789abcdef01234567, 0x67452301efcdab8967452301efcdab89); // 8..f0..7
    try test__bswapti2(0x67452301efcdab8967452301efcdab89, 0x89abcdef0123456789abcdef01234567);
    try test__bswapti2(0xdeadbeefdeadbeefdeadbeefdeadbeef, 0xefbeaddeefbeaddeefbeaddeefbeadde); // deadbeefdeadbeef
    try test__bswapti2(0xefbeaddeefbeaddeefbeaddeefbeadde, 0xdeadbeefdeadbeefdeadbeefdeadbeef);
    try test__bswapti2(0xdeadfacedeadfacedeadfacedeadface, 0xcefaaddecefaaddecefaaddecefaadde); // deadfacedeadface
    try test__bswapti2(0xcefaaddecefaaddecefaaddecefaadde, 0xdeadfacedeadfacedeadfacedeadface);
    try test__bswapti2(0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa, 0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa); // uninitialized memory
    try test__bswapti2(0x00000000000000000000000000000000, 0x00000000000000000000000000000000); // 0s
    try test__bswapti2(0xffffffffffffffffffffffffffffffff, 0xffffffffffffffffffffffffffffffff); // fs
}

const bitreverse = @import("bitreverse.zig");
const testing = @import("std").testing;

fn test__bitreverseti2(input: u128, expected: u128) !void {
    const result = bitreverse.__bitreverseti2(input);
    try testing.expectEqual(expected, result);
}

test "bitreverseti2" {
    try test__bitreverseti2(0x0123456789abcdef0123456789abcdef, 0xf7b3d591e6a2c480f7b3d591e6a2c480);
    try test__bitreverseti2(0xf7b3d591e6a2c480f7b3d591e6a2c480, 0x0123456789abcdef0123456789abcdef);
    try test__bitreverseti2(0x89abcdef000000000000000000000000, 0x000000000000000000000000f7b3d591);
    try test__bitreverseti2(0x000000000000000000000000f7b3d591, 0x89abcdef000000000000000000000000);
    try test__bitreverseti2(0x000000000000c0da2300000000000000, 0x00000000000000c45b03000000000000);
    try test__bitreverseti2(0x00000000000000c45b03000000000000, 0x000000000000c0da2300000000000000);
    try test__bitreverseti2(0x0000000000000000000000000000032f, 0xf4c00000000000000000000000000000);
    try test__bitreverseti2(0xf4c00000000000000000000000000000, 0x0000000000000000000000000000032f);
    try test__bitreverseti2(0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa, 0x55555555555555555555555555555555);
    try test__bitreverseti2(0x55555555555555555555555555555555, 0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa);
    try test__bitreverseti2(0x00000000000000000000000000000000, 0x00000000000000000000000000000000);
    try test__bitreverseti2(0xffffffffffffffffffffffffffffffff, 0xffffffffffffffffffffffffffffffff);
}

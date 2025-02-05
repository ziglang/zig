const bitreverse = @import("bitreverse.zig");
const testing = @import("std").testing;

fn test__bitreversesi2(input: u32, expected: u32) !void {
    const result = bitreverse.__bitreversesi2(input);
    try testing.expectEqual(expected, result);
}

test "bitreversesi2" {
    try test__bitreversesi2(0x01234567, 0xe6a2c480);
    try test__bitreversesi2(0xe6a2c480, 0x01234567);
    try test__bitreversesi2(0x89abcdef, 0xf7b3d591);
    try test__bitreversesi2(0xf7b3d591, 0x89abcdef);
    try test__bitreversesi2(0xc0da2300, 0x00c45b03);
    try test__bitreversesi2(0x00c45b03, 0xc0da2300);
    try test__bitreversesi2(0x0000032f, 0xf4c00000);
    try test__bitreversesi2(0xf4c00000, 0x0000032f);
    try test__bitreversesi2(0xaaaaaaaa, 0x55555555);
    try test__bitreversesi2(0x55555555, 0xaaaaaaaa);
    try test__bitreversesi2(0x00000000, 0x00000000);
    try test__bitreversesi2(0xffffffff, 0xffffffff);
}

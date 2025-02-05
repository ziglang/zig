const bitreverse = @import("bitreverse.zig");
const testing = @import("std").testing;

fn test__bitreversedi2(input: u64, expected: u64) !void {
    const result = bitreverse.__bitreversedi2(input);
    try testing.expectEqual(expected, result);
}

test "bitreversedi2" {
    try test__bitreversedi2(0x0123456789abcdef, 0xf7b3d591e6a2c480);
    try test__bitreversedi2(0xf7b3d591e6a2c480, 0x0123456789abcdef);
    try test__bitreversedi2(0x89abcdef00000000, 0x00000000f7b3d591);
    try test__bitreversedi2(0x00000000f7b3d591, 0x89abcdef00000000);
    try test__bitreversedi2(0x0000c0da23000000, 0x000000c45b030000);
    try test__bitreversedi2(0x000000c45b030000, 0x0000c0da23000000);
    try test__bitreversedi2(0x000000000000032f, 0xf4c0000000000000);
    try test__bitreversedi2(0xf4c0000000000000, 0x000000000000032f);
    try test__bitreversedi2(0xaaaaaaaaaaaaaaaa, 0x5555555555555555);
    try test__bitreversedi2(0x5555555555555555, 0xaaaaaaaaaaaaaaaa);
    try test__bitreversedi2(0x0000000000000000, 0x0000000000000000);
    try test__bitreversedi2(0xffffffffffffffff, 0xffffffffffffffff);
}

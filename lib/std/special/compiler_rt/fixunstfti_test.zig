const __fixunstfti = @import("fixunstfti.zig").__fixunstfti;
const testing = @import("std").testing;

fn test__fixunstfti(a: f128, expected: u128) !void {
    const x = __fixunstfti(a);
    try testing.expect(x == expected);
}

const inf128 = @bitCast(f128, @as(u128, 0x7fff0000000000000000000000000000));

test "fixunstfti" {
    try test__fixunstfti(inf128, 0xffffffffffffffffffffffffffffffff);

    try test__fixunstfti(0.0, 0);

    try test__fixunstfti(0.5, 0);
    try test__fixunstfti(0.99, 0);
    try test__fixunstfti(1.0, 1);
    try test__fixunstfti(1.5, 1);
    try test__fixunstfti(1.99, 1);
    try test__fixunstfti(2.0, 2);
    try test__fixunstfti(2.01, 2);
    try test__fixunstfti(-0.01, 0);
    try test__fixunstfti(-0.99, 0);

    try test__fixunstfti(0x1p+128, 0xffffffffffffffffffffffffffffffff);

    try test__fixunstfti(0x1.FFFFFEp+126, 0x7fffff80000000000000000000000000);
    try test__fixunstfti(0x1.FFFFFEp+127, 0xffffff00000000000000000000000000);
    try test__fixunstfti(0x1.FFFFFEp+128, 0xffffffffffffffffffffffffffffffff);
    try test__fixunstfti(0x1.FFFFFEp+129, 0xffffffffffffffffffffffffffffffff);
}

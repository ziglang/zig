const __fixunssfti = @import("fixunssfti.zig").__fixunssfti;
const testing = @import("std").testing;

fn test__fixunssfti(a: f32, expected: u128) !void {
    const x = __fixunssfti(a);
    try testing.expect(x == expected);
}

test "fixunssfti" {
    try test__fixunssfti(0.0, 0);

    try test__fixunssfti(0.5, 0);
    try test__fixunssfti(0.99, 0);
    try test__fixunssfti(1.0, 1);
    try test__fixunssfti(1.5, 1);
    try test__fixunssfti(1.99, 1);
    try test__fixunssfti(2.0, 2);
    try test__fixunssfti(2.01, 2);
    try test__fixunssfti(-0.5, 0);
    try test__fixunssfti(-0.99, 0);

    try test__fixunssfti(-1.0, 0);
    try test__fixunssfti(-1.5, 0);
    try test__fixunssfti(-1.99, 0);
    try test__fixunssfti(-2.0, 0);
    try test__fixunssfti(-2.01, 0);

    try test__fixunssfti(0x1.FFFFFEp+63, 0xFFFFFF0000000000);
    try test__fixunssfti(0x1.000000p+63, 0x8000000000000000);
    try test__fixunssfti(0x1.FFFFFEp+62, 0x7FFFFF8000000000);
    try test__fixunssfti(0x1.FFFFFCp+62, 0x7FFFFF0000000000);
    try test__fixunssfti(0x1.FFFFFEp+127, 0xFFFFFF00000000000000000000000000);
    try test__fixunssfti(0x1.000000p+127, 0x80000000000000000000000000000000);
    try test__fixunssfti(0x1.FFFFFEp+126, 0x7FFFFF80000000000000000000000000);
    try test__fixunssfti(0x1.FFFFFCp+126, 0x7FFFFF00000000000000000000000000);

    try test__fixunssfti(-0x1.FFFFFEp+62, 0x0000000000000000);
    try test__fixunssfti(-0x1.FFFFFCp+62, 0x0000000000000000);
    try test__fixunssfti(-0x1.FFFFFEp+126, 0x0000000000000000);
    try test__fixunssfti(-0x1.FFFFFCp+126, 0x0000000000000000);
}

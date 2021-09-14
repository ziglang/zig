const __fixunssfsi = @import("fixunssfsi.zig").__fixunssfsi;
const testing = @import("std").testing;

fn test__fixunssfsi(a: f32, expected: u32) !void {
    const x = __fixunssfsi(a);
    try testing.expect(x == expected);
}

test "fixunssfsi" {
    try test__fixunssfsi(0.0, 0);

    try test__fixunssfsi(0.5, 0);
    try test__fixunssfsi(0.99, 0);
    try test__fixunssfsi(1.0, 1);
    try test__fixunssfsi(1.5, 1);
    try test__fixunssfsi(1.99, 1);
    try test__fixunssfsi(2.0, 2);
    try test__fixunssfsi(2.01, 2);
    try test__fixunssfsi(-0.5, 0);
    try test__fixunssfsi(-0.99, 0);

    try test__fixunssfsi(-1.0, 0);
    try test__fixunssfsi(-1.5, 0);
    try test__fixunssfsi(-1.99, 0);
    try test__fixunssfsi(-2.0, 0);
    try test__fixunssfsi(-2.01, 0);

    try test__fixunssfsi(0x1.000000p+31, 0x80000000);
    try test__fixunssfsi(0x1.000000p+32, 0xFFFFFFFF);
    try test__fixunssfsi(0x1.FFFFFEp+31, 0xFFFFFF00);
    try test__fixunssfsi(0x1.FFFFFEp+30, 0x7FFFFF80);
    try test__fixunssfsi(0x1.FFFFFCp+30, 0x7FFFFF00);

    try test__fixunssfsi(-0x1.FFFFFEp+30, 0);
    try test__fixunssfsi(-0x1.FFFFFCp+30, 0);
}

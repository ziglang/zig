const __fixunssfdi = @import("fixunssfdi.zig").__fixunssfdi;
const testing = @import("std").testing;

fn test__fixunssfdi(a: f32, expected: u64) !void {
    const x = __fixunssfdi(a);
    try testing.expect(x == expected);
}

test "fixunssfdi" {
    try test__fixunssfdi(0.0, 0);

    try test__fixunssfdi(0.5, 0);
    try test__fixunssfdi(0.99, 0);
    try test__fixunssfdi(1.0, 1);
    try test__fixunssfdi(1.5, 1);
    try test__fixunssfdi(1.99, 1);
    try test__fixunssfdi(2.0, 2);
    try test__fixunssfdi(2.01, 2);
    try test__fixunssfdi(-0.5, 0);
    try test__fixunssfdi(-0.99, 0);

    try test__fixunssfdi(-1.0, 0);
    try test__fixunssfdi(-1.5, 0);
    try test__fixunssfdi(-1.99, 0);
    try test__fixunssfdi(-2.0, 0);
    try test__fixunssfdi(-2.01, 0);

    try test__fixunssfdi(0x1.FFFFFEp+63, 0xFFFFFF0000000000);
    try test__fixunssfdi(0x1.000000p+63, 0x8000000000000000);
    try test__fixunssfdi(0x1.FFFFFEp+62, 0x7FFFFF8000000000);
    try test__fixunssfdi(0x1.FFFFFCp+62, 0x7FFFFF0000000000);

    try test__fixunssfdi(-0x1.FFFFFEp+62, 0x0000000000000000);
    try test__fixunssfdi(-0x1.FFFFFCp+62, 0x0000000000000000);
}

const __fixunsdfsi = @import("fixunsdfsi.zig").__fixunsdfsi;
const testing = @import("std").testing;

fn test__fixunsdfsi(a: f64, expected: u32) !void {
    const x = __fixunsdfsi(a);
    try testing.expect(x == expected);
}

test "fixunsdfsi" {
    try test__fixunsdfsi(0.0, 0);

    try test__fixunsdfsi(0.5, 0);
    try test__fixunsdfsi(0.99, 0);
    try test__fixunsdfsi(1.0, 1);
    try test__fixunsdfsi(1.5, 1);
    try test__fixunsdfsi(1.99, 1);
    try test__fixunsdfsi(2.0, 2);
    try test__fixunsdfsi(2.01, 2);
    try test__fixunsdfsi(-0.5, 0);
    try test__fixunsdfsi(-0.99, 0);
    try test__fixunsdfsi(-1.0, 0);
    try test__fixunsdfsi(-1.5, 0);
    try test__fixunsdfsi(-1.99, 0);
    try test__fixunsdfsi(-2.0, 0);
    try test__fixunsdfsi(-2.01, 0);

    try test__fixunsdfsi(0x1.000000p+31, 0x80000000);
    try test__fixunsdfsi(0x1.000000p+32, 0xFFFFFFFF);
    try test__fixunsdfsi(0x1.FFFFFEp+31, 0xFFFFFF00);
    try test__fixunsdfsi(0x1.FFFFFEp+30, 0x7FFFFF80);
    try test__fixunsdfsi(0x1.FFFFFCp+30, 0x7FFFFF00);

    try test__fixunsdfsi(-0x1.FFFFFEp+30, 0);
    try test__fixunsdfsi(-0x1.FFFFFCp+30, 0);

    try test__fixunsdfsi(0x1.FFFFFFFEp+31, 0xFFFFFFFF);
    try test__fixunsdfsi(0x1.FFFFFFFC00000p+30, 0x7FFFFFFF);
    try test__fixunsdfsi(0x1.FFFFFFF800000p+30, 0x7FFFFFFE);
}

const __fixunsdfdi = @import("fixunsdfdi.zig").__fixunsdfdi;
const testing = @import("std").testing;

fn test__fixunsdfdi(a: f64, expected: u64) !void {
    const x = __fixunsdfdi(a);
    try testing.expect(x == expected);
}

test "fixunsdfdi" {
    //test__fixunsdfdi(0.0, 0);
    //test__fixunsdfdi(0.5, 0);
    //test__fixunsdfdi(0.99, 0);
    try test__fixunsdfdi(1.0, 1);
    try test__fixunsdfdi(1.5, 1);
    try test__fixunsdfdi(1.99, 1);
    try test__fixunsdfdi(2.0, 2);
    try test__fixunsdfdi(2.01, 2);
    try test__fixunsdfdi(-0.5, 0);
    try test__fixunsdfdi(-0.99, 0);
    try test__fixunsdfdi(-1.0, 0);
    try test__fixunsdfdi(-1.5, 0);
    try test__fixunsdfdi(-1.99, 0);
    try test__fixunsdfdi(-2.0, 0);
    try test__fixunsdfdi(-2.01, 0);

    try test__fixunsdfdi(0x1.FFFFFEp+62, 0x7FFFFF8000000000);
    try test__fixunsdfdi(0x1.FFFFFCp+62, 0x7FFFFF0000000000);

    try test__fixunsdfdi(-0x1.FFFFFEp+62, 0);
    try test__fixunsdfdi(-0x1.FFFFFCp+62, 0);

    try test__fixunsdfdi(0x1.FFFFFFFFFFFFFp+63, 0xFFFFFFFFFFFFF800);
    try test__fixunsdfdi(0x1.0000000000000p+63, 0x8000000000000000);
    try test__fixunsdfdi(0x1.FFFFFFFFFFFFFp+62, 0x7FFFFFFFFFFFFC00);
    try test__fixunsdfdi(0x1.FFFFFFFFFFFFEp+62, 0x7FFFFFFFFFFFF800);

    try test__fixunsdfdi(-0x1.FFFFFFFFFFFFFp+62, 0);
    try test__fixunsdfdi(-0x1.FFFFFFFFFFFFEp+62, 0);
}

const std = @import("std");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const expectEqualSlices = std.testing.expectEqualSlices;
const maxInt = std.math.maxInt;
const minInt = std.math.minInt;
const mem = std.mem;

test "assignment operators" {
    var i: u32 = 0;
    i += 5;
    try expect(i == 5);
    i -= 2;
    try expect(i == 3);
    i *= 20;
    try expect(i == 60);
    i /= 3;
    try expect(i == 20);
    i %= 11;
    try expect(i == 9);
    i <<= 1;
    try expect(i == 18);
    i >>= 2;
    try expect(i == 4);
    i = 6;
    i &= 5;
    try expect(i == 4);
    i ^= 6;
    try expect(i == 2);
    i = 6;
    i |= 3;
    try expect(i == 7);
}

test "three expr in a row" {
    try testThreeExprInARow(false, true);
    comptime try testThreeExprInARow(false, true);
}
fn testThreeExprInARow(f: bool, t: bool) !void {
    try assertFalse(f or f or f);
    try assertFalse(t and t and f);
    try assertFalse(1 | 2 | 4 != 7);
    try assertFalse(3 ^ 6 ^ 8 != 13);
    try assertFalse(7 & 14 & 28 != 4);
    try assertFalse(9 << 1 << 2 != 9 << 3);
    try assertFalse(90 >> 1 >> 2 != 90 >> 3);
    try assertFalse(100 - 1 + 1000 != 1099);
    try assertFalse(5 * 4 / 2 % 3 != 1);
    try assertFalse(@as(i32, @as(i32, 5)) != 5);
    try assertFalse(!!false);
    try assertFalse(@as(i32, 7) != --(@as(i32, 7)));
}
fn assertFalse(b: bool) !void {
    try expect(!b);
}

test "@clz" {
    try testClz();
    comptime try testClz();
}

fn testClz() !void {
    try expect(testOneClz(u8, 0b10001010) == 0);
    try expect(testOneClz(u8, 0b00001010) == 4);
    try expect(testOneClz(u8, 0b00011010) == 3);
    try expect(testOneClz(u8, 0b00000000) == 8);
    try expect(testOneClz(u128, 0xffffffffffffffff) == 64);
    try expect(testOneClz(u128, 0x10000000000000000) == 63);
}

fn testOneClz(comptime T: type, x: T) u32 {
    return @clz(T, x);
}

test "const number literal" {
    const one = 1;
    const eleven = ten + one;

    try expect(eleven == 11);
}
const ten = 10;

test "float equality" {
    const x: f64 = 0.012;
    const y: f64 = x + 1.0;

    try testFloatEqualityImpl(x, y);
    comptime try testFloatEqualityImpl(x, y);
}

fn testFloatEqualityImpl(x: f64, y: f64) !void {
    const y2 = x + 1.0;
    try expect(y == y2);
}

test "hex float literal parsing" {
    comptime try expect(0x1.0 == 1.0);
}

test "quad hex float literal parsing in range" {
    const a = 0x1.af23456789bbaaab347645365cdep+5;
    const b = 0x1.dedafcff354b6ae9758763545432p-9;
    const c = 0x1.2f34dd5f437e849b4baab754cdefp+4534;
    const d = 0x1.edcbff8ad76ab5bf46463233214fp-435;
    _ = a;
    _ = b;
    _ = c;
    _ = d;
}

test "underscore separator parsing" {
    try expect(0_0_0_0 == 0);
    try expect(1_234_567 == 1234567);
    try expect(001_234_567 == 1234567);
    try expect(0_0_1_2_3_4_5_6_7 == 1234567);

    try expect(0b0_0_0_0 == 0);
    try expect(0b1010_1010 == 0b10101010);
    try expect(0b0000_1010_1010 == 0b10101010);
    try expect(0b1_0_1_0_1_0_1_0 == 0b10101010);

    try expect(0o0_0_0_0 == 0);
    try expect(0o1010_1010 == 0o10101010);
    try expect(0o0000_1010_1010 == 0o10101010);
    try expect(0o1_0_1_0_1_0_1_0 == 0o10101010);

    try expect(0x0_0_0_0 == 0);
    try expect(0x1010_1010 == 0x10101010);
    try expect(0x0000_1010_1010 == 0x10101010);
    try expect(0x1_0_1_0_1_0_1_0 == 0x10101010);

    try expect(123_456.789_000e1_0 == 123456.789000e10);
    try expect(0_1_2_3_4_5_6.7_8_9_0_0_0e0_0_1_0 == 123456.789000e10);

    try expect(0x1234_5678.9ABC_DEF0p-1_0 == 0x12345678.9ABCDEF0p-10);
    try expect(0x1_2_3_4_5_6_7_8.9_A_B_C_D_E_F_0p-0_0_0_1_0 == 0x12345678.9ABCDEF0p-10);
}

test "hex float literal within range" {
    const a = 0x1.0p16383;
    const b = 0x0.1p16387;
    const c = 0x1.0p-16382;
    _ = a;
    _ = b;
    _ = c;
}

test "comptime_int addition" {
    comptime {
        try expect(35361831660712422535336160538497375248 + 101752735581729509668353361206450473702 == 137114567242441932203689521744947848950);
        try expect(594491908217841670578297176641415611445982232488944558774612 + 390603545391089362063884922208143568023166603618446395589768 == 985095453608931032642182098849559179469148836107390954364380);
    }
}

test "comptime_int multiplication" {
    comptime {
        try expect(
            45960427431263824329884196484953148229 * 128339149605334697009938835852565949723 == 5898522172026096622534201617172456926982464453350084962781392314016180490567,
        );
        try expect(
            594491908217841670578297176641415611445982232488944558774612 * 390603545391089362063884922208143568023166603618446395589768 == 232210647056203049913662402532976186578842425262306016094292237500303028346593132411865381225871291702600263463125370016,
        );
    }
}

test "comptime_int shifting" {
    comptime {
        try expect((@as(u128, 1) << 127) == 0x80000000000000000000000000000000);
    }
}

test "comptime_int multi-limb shift and mask" {
    comptime {
        var a = 0xefffffffa0000001eeeeeeefaaaaaaab;

        try expect(@as(u32, a & 0xffffffff) == 0xaaaaaaab);
        a >>= 32;
        try expect(@as(u32, a & 0xffffffff) == 0xeeeeeeef);
        a >>= 32;
        try expect(@as(u32, a & 0xffffffff) == 0xa0000001);
        a >>= 32;
        try expect(@as(u32, a & 0xffffffff) == 0xefffffff);
        a >>= 32;

        try expect(a == 0);
    }
}

test "comptime_int multi-limb partial shift right" {
    comptime {
        var a = 0x1ffffffffeeeeeeee;
        a >>= 16;
        try expect(a == 0x1ffffffffeeee);
    }
}

test "xor" {
    try test_xor();
    comptime try test_xor();
}

fn test_xor() !void {
    try testOneXor(0xFF, 0x00, 0xFF);
    try testOneXor(0xF0, 0x0F, 0xFF);
    try testOneXor(0xFF, 0xF0, 0x0F);
    try testOneXor(0xFF, 0x0F, 0xF0);
    try testOneXor(0xFF, 0xFF, 0x00);
}

fn testOneXor(a: u8, b: u8, c: u8) !void {
    try expect(a ^ b == c);
}

test "comptime_int xor" {
    comptime {
        try expect(0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF ^ 0x00000000000000000000000000000000 == 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF);
        try expect(0xFFFFFFFFFFFFFFFF0000000000000000 ^ 0x0000000000000000FFFFFFFFFFFFFFFF == 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF);
        try expect(0xFFFFFFFFFFFFFFFF0000000000000000 ^ 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF == 0x0000000000000000FFFFFFFFFFFFFFFF);
        try expect(0x0000000000000000FFFFFFFFFFFFFFFF ^ 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF == 0xFFFFFFFFFFFFFFFF0000000000000000);
        try expect(0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF ^ 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF == 0x00000000000000000000000000000000);
        try expect(0xFFFFFFFF00000000FFFFFFFF00000000 ^ 0x00000000FFFFFFFF00000000FFFFFFFF == 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF);
        try expect(0xFFFFFFFF00000000FFFFFFFF00000000 ^ 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF == 0x00000000FFFFFFFF00000000FFFFFFFF);
        try expect(0x00000000FFFFFFFF00000000FFFFFFFF ^ 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF == 0xFFFFFFFF00000000FFFFFFFF00000000);
    }
}

test "comptime_int param and return" {
    const a = comptimeAdd(35361831660712422535336160538497375248, 101752735581729509668353361206450473702);
    try expect(a == 137114567242441932203689521744947848950);

    const b = comptimeAdd(594491908217841670578297176641415611445982232488944558774612, 390603545391089362063884922208143568023166603618446395589768);
    try expect(b == 985095453608931032642182098849559179469148836107390954364380);
}

fn comptimeAdd(comptime a: comptime_int, comptime b: comptime_int) comptime_int {
    return a + b;
}

test "binary not" {
    try expect(comptime x: {
        break :x ~@as(u16, 0b1010101010101010) == 0b0101010101010101;
    });
    try expect(comptime x: {
        break :x ~@as(u64, 2147483647) == 18446744071562067968;
    });
    try testBinaryNot(0b1010101010101010);
}

fn testBinaryNot(x: u16) !void {
    try expect(~x == 0b0101010101010101);
}

test "division" {
    try testDivision();
    comptime try testDivision();
}
fn testDivision() !void {
    try expect(div(u32, 13, 3) == 4);
    try expect(div(f16, 1.0, 2.0) == 0.5);
    try expect(div(f32, 1.0, 2.0) == 0.5);

    try expect(divExact(u32, 55, 11) == 5);
    try expect(divExact(i32, -55, 11) == -5);
    try expect(divExact(f16, 55.0, 11.0) == 5.0);
    try expect(divExact(f16, -55.0, 11.0) == -5.0);
    try expect(divExact(f32, 55.0, 11.0) == 5.0);
    try expect(divExact(f32, -55.0, 11.0) == -5.0);

    try expect(divFloor(i32, 5, 3) == 1);
    try expect(divFloor(i32, -5, 3) == -2);
    try expect(divFloor(f16, 5.0, 3.0) == 1.0);
    try expect(divFloor(f16, -5.0, 3.0) == -2.0);
    try expect(divFloor(f32, 5.0, 3.0) == 1.0);
    try expect(divFloor(f32, -5.0, 3.0) == -2.0);
    try expect(divFloor(i32, -0x80000000, -2) == 0x40000000);
    try expect(divFloor(i32, 0, -0x80000000) == 0);
    try expect(divFloor(i32, -0x40000001, 0x40000000) == -2);
    try expect(divFloor(i32, -0x80000000, 1) == -0x80000000);
    try expect(divFloor(i32, 10, 12) == 0);
    try expect(divFloor(i32, -14, 12) == -2);
    try expect(divFloor(i32, -2, 12) == -1);

    try expect(divTrunc(i32, 5, 3) == 1);
    try expect(divTrunc(i32, -5, 3) == -1);
    try expect(divTrunc(i32, 9, -10) == 0);
    try expect(divTrunc(i32, -9, 10) == 0);
    try expect(divTrunc(f16, 5.0, 3.0) == 1.0);
    try expect(divTrunc(f16, -5.0, 3.0) == -1.0);
    try expect(divTrunc(f16, 9.0, -10.0) == 0.0);
    try expect(divTrunc(f16, -9.0, 10.0) == 0.0);
    try expect(divTrunc(f32, 5.0, 3.0) == 1.0);
    try expect(divTrunc(f32, -5.0, 3.0) == -1.0);
    try expect(divTrunc(f32, 9.0, -10.0) == 0.0);
    try expect(divTrunc(f32, -9.0, 10.0) == 0.0);
    try expect(divTrunc(f64, 5.0, 3.0) == 1.0);
    try expect(divTrunc(f64, -5.0, 3.0) == -1.0);
    try expect(divTrunc(f64, 9.0, -10.0) == 0.0);
    try expect(divTrunc(f64, -9.0, 10.0) == 0.0);
    try expect(divTrunc(i32, 10, 12) == 0);
    try expect(divTrunc(i32, -14, 12) == -1);
    try expect(divTrunc(i32, -2, 12) == 0);

    try expect(mod(i32, 10, 12) == 10);
    try expect(mod(i32, -14, 12) == 10);
    try expect(mod(i32, -2, 12) == 10);

    comptime {
        try expect(
            1194735857077236777412821811143690633098347576 % 508740759824825164163191790951174292733114988 == 177254337427586449086438229241342047632117600,
        );
        try expect(
            @rem(-1194735857077236777412821811143690633098347576, 508740759824825164163191790951174292733114988) == -177254337427586449086438229241342047632117600,
        );
        try expect(
            1194735857077236777412821811143690633098347576 / 508740759824825164163191790951174292733114988 == 2,
        );
        try expect(
            @divTrunc(-1194735857077236777412821811143690633098347576, 508740759824825164163191790951174292733114988) == -2,
        );
        try expect(
            @divTrunc(1194735857077236777412821811143690633098347576, -508740759824825164163191790951174292733114988) == -2,
        );
        try expect(
            @divTrunc(-1194735857077236777412821811143690633098347576, -508740759824825164163191790951174292733114988) == 2,
        );
        try expect(
            4126227191251978491697987544882340798050766755606969681711 % 10 == 1,
        );
    }
}
fn div(comptime T: type, a: T, b: T) T {
    return a / b;
}
fn divExact(comptime T: type, a: T, b: T) T {
    return @divExact(a, b);
}
fn divFloor(comptime T: type, a: T, b: T) T {
    return @divFloor(a, b);
}
fn divTrunc(comptime T: type, a: T, b: T) T {
    return @divTrunc(a, b);
}
fn mod(comptime T: type, a: T, b: T) T {
    return @mod(a, b);
}

test "unsigned wrapping" {
    try testUnsignedWrappingEval(maxInt(u32));
    comptime try testUnsignedWrappingEval(maxInt(u32));
}
fn testUnsignedWrappingEval(x: u32) !void {
    const zero = x +% 1;
    try expect(zero == 0);
    const orig = zero -% 1;
    try expect(orig == maxInt(u32));
}

test "signed wrapping" {
    try testSignedWrappingEval(maxInt(i32));
    comptime try testSignedWrappingEval(maxInt(i32));
}
fn testSignedWrappingEval(x: i32) !void {
    const min_val = x +% 1;
    try expect(min_val == minInt(i32));
    const max_val = min_val -% 1;
    try expect(max_val == maxInt(i32));
}

test "signed negation wrapping" {
    try testSignedNegationWrappingEval(minInt(i16));
    comptime try testSignedNegationWrappingEval(minInt(i16));
}
fn testSignedNegationWrappingEval(x: i16) !void {
    try expect(x == -32768);
    const neg = -%x;
    try expect(neg == -32768);
}

test "unsigned negation wrapping" {
    try testUnsignedNegationWrappingEval(1);
    comptime try testUnsignedNegationWrappingEval(1);
}
fn testUnsignedNegationWrappingEval(x: u16) !void {
    try expect(x == 1);
    const neg = -%x;
    try expect(neg == maxInt(u16));
}

test "unsigned 64-bit division" {
    try test_u64_div();
    comptime try test_u64_div();
}
fn test_u64_div() !void {
    const result = divWithResult(1152921504606846976, 34359738365);
    try expect(result.quotient == 33554432);
    try expect(result.remainder == 100663296);
}
fn divWithResult(a: u64, b: u64) DivResult {
    return DivResult{
        .quotient = a / b,
        .remainder = a % b,
    };
}
const DivResult = struct {
    quotient: u64,
    remainder: u64,
};

test "truncating shift right" {
    try testShrTrunc(maxInt(u16));
    comptime try testShrTrunc(maxInt(u16));
}
fn testShrTrunc(x: u16) !void {
    const shifted = x >> 1;
    try expect(shifted == 32767);
}

test "f128" {
    try test_f128();
    comptime try test_f128();
}

fn make_f128(x: f128) f128 {
    return x;
}

fn test_f128() !void {
    try expect(@sizeOf(f128) == 16);
    try expect(make_f128(1.0) == 1.0);
    try expect(make_f128(1.0) != 1.1);
    try expect(make_f128(1.0) > 0.9);
    try expect(make_f128(1.0) >= 0.9);
    try expect(make_f128(1.0) >= 1.0);
    try should_not_be_zero(1.0);
}

fn should_not_be_zero(x: f128) !void {
    try expect(x != 0.0);
}

test "128-bit multiplication" {
    var a: i128 = 3;
    var b: i128 = 2;
    var c = a * b;
    try expect(c == 6);
}

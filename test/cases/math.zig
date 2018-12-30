const std = @import("std");
const assertOrPanic = std.debug.assertOrPanic;
const maxInt = std.math.maxInt;
const minInt = std.math.minInt;

test "remainder division" {
    comptime remdiv(f16);
    comptime remdiv(f32);
    comptime remdiv(f64);
    comptime remdiv(f128);
    remdiv(f16);
    remdiv(f64);
    remdiv(f128);
}

fn remdiv(comptime T: type) void {
    assertOrPanic(T(1) == T(1) % T(2));
    assertOrPanic(T(1) == T(7) % T(3));
}

test "@sqrt" {
    testSqrt(f64, 12.0);
    comptime testSqrt(f64, 12.0);
    testSqrt(f32, 13.0);
    comptime testSqrt(f32, 13.0);
    testSqrt(f16, 13.0);
    comptime testSqrt(f16, 13.0);

    const x = 14.0;
    const y = x * x;
    const z = @sqrt(@typeOf(y), y);
    comptime assertOrPanic(z == x);
}

fn testSqrt(comptime T: type, x: T) void {
    assertOrPanic(@sqrt(T, x * x) == x);
}

test "comptime_int param and return" {
    const a = comptimeAdd(35361831660712422535336160538497375248, 101752735581729509668353361206450473702);
    assertOrPanic(a == 137114567242441932203689521744947848950);

    const b = comptimeAdd(594491908217841670578297176641415611445982232488944558774612, 390603545391089362063884922208143568023166603618446395589768);
    assertOrPanic(b == 985095453608931032642182098849559179469148836107390954364380);
}

fn comptimeAdd(comptime a: comptime_int, comptime b: comptime_int) comptime_int {
    return a + b;
}

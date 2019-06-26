const expect = @import("std").testing.expect;
const pi = @import("std").math.pi;
const e = @import("std").math.e;

test "@sqrt" {
    comptime testSqrt();
    testSqrt();
}

fn testSqrt() void {
    {
        var a: f16 = 4;
        expect(@sqrt(f16, a) == 2);
    }
    {
        var a: f32 = 9;
        expect(@sqrt(f32, a) == 3);
    }
    {
        var a: f64 = 25;
        expect(@sqrt(f64, a) == 5);
    }
    {
        const a: comptime_float = 25.0;
        expect(@sqrt(comptime_float, a) == 5.0);
    }
    // Waiting on a c.zig implementation
    //{
    //    var a: f128 = 49;
    //    expect(@sqrt(f128, a) == 7);
    //}
}

test "@sin" {
    comptime testSin();
    testSin();
}

fn testSin() void {
    // TODO - this is actually useful and should be implemented
    // (all the trig functions for f16)
    // but will probably wait till self-hosted
    //{
    //    var a: f16 = pi;
    //    expect(@sin(f16, a/2) == 1);
    //}
    {
        var a: f32 = 0;
        expect(@sin(f32, a) == 0);
    }
    {
        var a: f64 = 0;
        expect(@sin(f64, a) == 0);
    }
    // TODO
    //{
    //    var a: f16 = pi;
    //    expect(@sqrt(f128, a/2) == 1);
    //}
}

test "@cos" {
    comptime testCos();
    testCos();
}

fn testCos() void {
    {
        var a: f32 = 0;
        expect(@cos(f32, a) == 1);
    }
    {
        var a: f64 = 0;
        expect(@cos(f64, a) == 1);
    }
}

test "@exp" {
    comptime testExp();
    testExp();
}

fn testExp() void {
    {
        var a: f32 = 0;
        expect(@exp(f32, a) == 1);
    }
    {
        var a: f64 = 0;
        expect(@exp(f64, a) == 1);
    }
}

test "@exp2" {
    comptime testExp2();
    testExp2();
}

fn testExp2() void {
    {
        var a: f32 = 2;
        expect(@exp2(f32, a) == 4);
    }
    {
        var a: f64 = 2;
        expect(@exp2(f64, a) == 4);
    }
}

test "@ln" {
    // Old musl (and glibc?), and our current math.ln implementation do not return 1
    // so also accept those values.
    comptime testLn();
    testLn();
}

fn testLn() void {
    {
        var a: f32 = e;
        expect(@ln(f32, a) == 1 or @ln(f32, a) == @bitCast(f32, u32(0x3f7fffff)));
    }
    {
        var a: f64 = e;
        expect(@ln(f64, a) == 1 or @ln(f64, a) == @bitCast(f64, u64(0x3ff0000000000000)));
    }
}

test "@log2" {
    comptime testLog2();
    testLog2();
}

fn testLog2() void {
    {
        var a: f32 = 4;
        expect(@log2(f32, a) == 2);
    }
    {
        var a: f64 = 4;
        expect(@log2(f64, a) == 2);
    }
}

test "@log10" {
    comptime testLog10();
    testLog10();
}

fn testLog10() void {
    {
        var a: f32 = 100;
        expect(@log10(f32, a) == 2);
    }
    {
        var a: f64 = 1000;
        expect(@log10(f64, a) == 3);
    }
}

test "@fabs" {
    comptime testFabs();
    testFabs();
}

fn testFabs() void {
    {
        var a: f32 = -2.5;
        var b: f32 = 2.5;
        expect(@fabs(f32, a) == 2.5);
        expect(@fabs(f32, b) == 2.5);
    }
    {
        var a: f64 = -2.5;
        var b: f64 = 2.5;
        expect(@fabs(f64, a) == 2.5);
        expect(@fabs(f64, b) == 2.5);
    }
}

test "@floor" {
    comptime testFloor();
    testFloor();
}

fn testFloor() void {
    {
        var a: f32 = 2.1;
        expect(@floor(f32, a) == 2);
    }
    {
        var a: f64 = 3.5;
        expect(@floor(f64, a) == 3);
    }
}

test "@ceil" {
    comptime testCeil();
    testCeil();
}

fn testCeil() void {
    {
        var a: f32 = 2.1;
        expect(@ceil(f32, a) == 3);
    }
    {
        var a: f64 = 3.5;
        expect(@ceil(f64, a) == 4);
    }
}

test "@trunc" {
    comptime testTrunc();
    testTrunc();
}

fn testTrunc() void {
    {
        var a: f32 = 2.1;
        expect(@trunc(f32, a) == 2);
    }
    {
        var a: f64 = -3.5;
        expect(@trunc(f64, a) == -3);
    }
}

// This is waiting on library support for the Windows build (not sure why the other's don't need it)
//test "@nearbyInt" {
//    comptime testNearbyInt();
//    testNearbyInt();
//}

//fn testNearbyInt() void {
//    {
//        var a: f32 = 2.1;
//        expect(@nearbyInt(f32, a) == 2);
//    }
//    {
//        var a: f64 = -3.75;
//        expect(@nearbyInt(f64, a) == -4);
//    }
//}

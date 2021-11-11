const expect = @import("std").testing.expect;

test "@mulAdd" {
    comptime try testMulAdd();
    try testMulAdd();
}

fn testMulAdd() !void {
    {
        var a: f16 = 5.5;
        var b: f16 = 2.5;
        var c: f16 = 6.25;
        try expect(@mulAdd(f16, a, b, c) == 20);
    }
    {
        var a: f32 = 5.5;
        var b: f32 = 2.5;
        var c: f32 = 6.25;
        try expect(@mulAdd(f32, a, b, c) == 20);
    }
    {
        var a: f64 = 5.5;
        var b: f64 = 2.5;
        var c: f64 = 6.25;
        try expect(@mulAdd(f64, a, b, c) == 20);
    }
    {
        var a: f16 = 5.5;
        var b: f128 = 2.5;
        var c: f128 = 6.25;
        try expect(@mulAdd(f128, a, b, c) == 20);
    }
}

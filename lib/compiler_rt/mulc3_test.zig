const std = @import("std");
const math = std.math;
const expect = std.testing.expect;

const Complex = @import("./mulc3.zig").Complex;
const __mulhc3 = @import("./mulhc3.zig").__mulhc3;
const __mulsc3 = @import("./mulsc3.zig").__mulsc3;
const __muldc3 = @import("./muldc3.zig").__muldc3;
const __mulxc3 = @import("./mulxc3.zig").__mulxc3;
const __multc3 = @import("./multc3.zig").__multc3;

test {
    try testMul(f16, __mulhc3);
    try testMul(f32, __mulsc3);
    try testMul(f64, __muldc3);
    try testMul(f80, __mulxc3);
    try testMul(f128, __multc3);
}

fn testMul(comptime T: type, comptime f: fn (T, T, T, T) callconv(.C) Complex(T)) !void {
    {
        var a: T = 1.0;
        var b: T = 0.0;
        var c: T = -1.0;
        var d: T = 0.0;

        const result = f(a, b, c, d);
        try expect(result.real == -1.0);
        try expect(result.imag == 0.0);
    }
    {
        var a: T = 1.0;
        var b: T = 0.0;
        var c: T = -4.0;
        var d: T = 0.0;

        const result = f(a, b, c, d);
        try expect(result.real == -4.0);
        try expect(result.imag == 0.0);
    }
    {
        // if one operand is an infinity and the other operand is a nonzero finite number or an infinity,
        // then the result of the * operator is an infinity;
        var a: T = math.inf(T);
        var b: T = -math.inf(T);
        var c: T = 1.0;
        var d: T = 0.0;

        const result = f(a, b, c, d);
        try expect(result.real == math.inf(T));
        try expect(result.imag == -math.inf(T));
    }
    {
        // if one operand is an infinity and the other operand is a nonzero finite number or an infinity,
        // then the result of the * operator is an infinity;
        var a: T = math.inf(T);
        var b: T = -1.0;
        var c: T = 1.0;
        var d: T = math.inf(T);

        const result = f(a, b, c, d);
        try expect(result.real == math.inf(T));
        try expect(result.imag == math.inf(T));
    }
}

const std = @import("std");
const math = std.math;
const expect = std.testing.expect;

const Complex = @import("./mulc3.zig").Complex;
const __divhc3 = @import("./divhc3.zig").__divhc3;
const __divsc3 = @import("./divsc3.zig").__divsc3;
const __divdc3 = @import("./divdc3.zig").__divdc3;
const __divxc3 = @import("./divxc3.zig").__divxc3;
const __divtc3 = @import("./divtc3.zig").__divtc3;

test {
    try testDiv(f16, __divhc3);
    try testDiv(f32, __divsc3);
    try testDiv(f64, __divdc3);
    try testDiv(f80, __divxc3);
    try testDiv(f128, __divtc3);
}

fn testDiv(comptime T: type, comptime f: fn (T, T, T, T) callconv(.C) Complex(T)) !void {
    {
        const a: T = 1.0;
        const b: T = 0.0;
        const c: T = -1.0;
        const d: T = 0.0;

        const result = f(a, b, c, d);
        try expect(result.real == -1.0);
        try expect(result.imag == 0.0);
    }
    {
        const a: T = 1.0;
        const b: T = 0.0;
        const c: T = -4.0;
        const d: T = 0.0;

        const result = f(a, b, c, d);
        try expect(result.real == -0.25);
        try expect(result.imag == 0.0);
    }
    {
        // if the first operand is an infinity and the second operand is a finite number, then the
        // result of the / operator is an infinity;
        const a: T = -math.inf(T);
        const b: T = 0.0;
        const c: T = -4.0;
        const d: T = 1.0;

        const result = f(a, b, c, d);
        try expect(result.real == math.inf(T));
        try expect(result.imag == math.inf(T));
    }
    {
        // if the first operand is a finite number and the second operand is an infinity, then the
        // result of the / operator is a zero;
        const a: T = 17.2;
        const b: T = 0.0;
        const c: T = -math.inf(T);
        const d: T = 0.0;

        const result = f(a, b, c, d);
        try expect(result.real == -0.0);
        try expect(result.imag == 0.0);
    }
    {
        // if the first operand is a nonzero finite number or an infinity and the second operand is
        // a zero, then the result of the / operator is an infinity
        const a: T = 1.1;
        const b: T = 0.1;
        const c: T = 0.0;
        const d: T = 0.0;

        const result = f(a, b, c, d);
        try expect(result.real == math.inf(T));
        try expect(result.imag == math.inf(T));
    }
}

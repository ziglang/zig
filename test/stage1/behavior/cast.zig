const std = @import("std");
const assertOrPanic = std.debug.assertOrPanic;
const mem = std.mem;
const maxInt = std.math.maxInt;

test "int to ptr cast" {
    const x = usize(13);
    const y = @intToPtr(*u8, x);
    const z = @ptrToInt(y);
    assertOrPanic(z == 13);
}

test "integer literal to pointer cast" {
    const vga_mem = @intToPtr(*u16, 0xB8000);
    assertOrPanic(@ptrToInt(vga_mem) == 0xB8000);
}

test "pointer reinterpret const float to int" {
    const float: f64 = 5.99999999999994648725e-01;
    const float_ptr = &float;
    const int_ptr = @ptrCast(*const i32, float_ptr);
    const int_val = int_ptr.*;
    assertOrPanic(int_val == 858993411);
}

test "implicitly cast indirect pointer to maybe-indirect pointer" {
    const S = struct {
        const Self = @This();
        x: u8,
        fn constConst(p: *const *const Self) u8 {
            return p.*.x;
        }
        fn maybeConstConst(p: ?*const *const Self) u8 {
            return p.?.*.x;
        }
        fn constConstConst(p: *const *const *const Self) u8 {
            return p.*.*.x;
        }
        fn maybeConstConstConst(p: ?*const *const *const Self) u8 {
            return p.?.*.*.x;
        }
    };
    const s = S{ .x = 42 };
    const p = &s;
    const q = &p;
    const r = &q;
    assertOrPanic(42 == S.constConst(q));
    assertOrPanic(42 == S.maybeConstConst(q));
    assertOrPanic(42 == S.constConstConst(r));
    assertOrPanic(42 == S.maybeConstConstConst(r));
}

test "explicit cast from integer to error type" {
    testCastIntToErr(error.ItBroke);
    comptime testCastIntToErr(error.ItBroke);
}
fn testCastIntToErr(err: anyerror) void {
    const x = @errorToInt(err);
    const y = @intToError(x);
    assertOrPanic(error.ItBroke == y);
}

test "peer resolve arrays of different size to const slice" {
    assertOrPanic(mem.eql(u8, boolToStr(true), "true"));
    assertOrPanic(mem.eql(u8, boolToStr(false), "false"));
    comptime assertOrPanic(mem.eql(u8, boolToStr(true), "true"));
    comptime assertOrPanic(mem.eql(u8, boolToStr(false), "false"));
}
fn boolToStr(b: bool) []const u8 {
    return if (b) "true" else "false";
}


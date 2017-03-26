const assert = @import("debug.zig").assert;

pub const Cmp = enum {
    Equal,
    Greater,
    Less,
};

pub fn min(x: var, y: var) -> @typeOf(x + y) {
    if (x < y) x else y
}

pub fn max(x: var, y: var) -> @typeOf(x + y) {
    if (x > y) x else y
}

error Overflow;
pub fn mulOverflow(comptime T: type, a: T, b: T) -> %T {
    var answer: T = undefined;
    if (@mulWithOverflow(T, a, b, &answer)) error.Overflow else answer
}
pub fn addOverflow(comptime T: type, a: T, b: T) -> %T {
    var answer: T = undefined;
    if (@addWithOverflow(T, a, b, &answer)) error.Overflow else answer
}
pub fn subOverflow(comptime T: type, a: T, b: T) -> %T {
    var answer: T = undefined;
    if (@subWithOverflow(T, a, b, &answer)) error.Overflow else answer
}
pub fn shlOverflow(comptime T: type, a: T, b: T) -> %T {
    var answer: T = undefined;
    if (@shlWithOverflow(T, a, b, &answer)) error.Overflow else answer
}

pub fn log(comptime base: usize, value: var) -> @typeOf(value) {
    const T = @typeOf(value);
    if (@isInteger(T)) {
        if (base == 2) {
            return T.bit_count - 1 - @clz(value);
        } else {
            @compileError("TODO implement log for non base 2 integers");
        }
    } else if (@isFloat(T)) {
        @compileError("TODO implement log for floats");
    } else {
        @compileError("log expects integer or float, found '" ++ @typeName(T) ++ "'");
    }
}

/// x must be an integer or a float
/// Note that this causes undefined behavior if
/// @typeOf(x).is_signed && x == @minValue(@typeOf(x)).
pub fn abs(x: var) -> @typeOf(x) {
    const T = @typeOf(x);
    if (@isInteger(T)) {
        return if (x < 0) -x else x;
    } else if (@isFloat(T)) {
        @compileError("TODO implement abs for floats");
    } else {
        unreachable;
    }
}
fn getReturnTypeForAbs(comptime T: type) -> type {
    if (@isInteger(T)) {
        return @intType(false, T.bit_count);
    } else {
        return T;
    }
}

test "testMath" {
    testMathImpl();
    comptime testMathImpl();
}

fn testMathImpl() {
    assert(%%mulOverflow(i32, 3, 4) == 12);
    assert(%%addOverflow(i32, 3, 4) == 7);
    assert(%%subOverflow(i32, 3, 4) == -1);
    assert(%%shlOverflow(i32, 0b11, 4) == 0b110000);
}

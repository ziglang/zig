//! For arithmetic operations which can trigger Illegal Behavior, this test evaluates those
//! operations with undefined operands (or partially-undefined vector operands), and ensures that a
//! compile error is emitted as expected.

comptime {
    // Total expected errors:
    // 29*14*6 + 26*14*5 = 4256

    testType(u8);
    testType(i8);
    testType(u32);
    testType(i32);
    testType(u500);
    testType(i500);

    testType(f16);
    testType(f32);
    testType(f64);
    testType(f80);
    testType(f128);
}

fn testType(comptime Scalar: type) void {
    // zig fmt: off
    testInner(Scalar,             undefined,                 1                        );
    testInner(Scalar,             undefined,                 undefined                );
    testInner(@Vector(2, Scalar), .{ undefined, undefined }, .{ undefined, undefined });
    testInner(@Vector(2, Scalar), .{ undefined, undefined }, .{ 1,         2         });
    testInner(@Vector(2, Scalar), .{ undefined, undefined }, .{ 1,         undefined });
    testInner(@Vector(2, Scalar), .{ undefined, undefined }, .{ undefined, 2         });
    testInner(@Vector(2, Scalar), .{ 1,         undefined }, .{ undefined, undefined });
    testInner(@Vector(2, Scalar), .{ 1,         undefined }, .{ 1,         2         });
    testInner(@Vector(2, Scalar), .{ 1,         undefined }, .{ 1,         undefined });
    testInner(@Vector(2, Scalar), .{ 1,         undefined }, .{ undefined, 2         });
    testInner(@Vector(2, Scalar), .{ undefined, 2         }, .{ undefined, undefined });
    testInner(@Vector(2, Scalar), .{ undefined, 2         }, .{ 1,         2         });
    testInner(@Vector(2, Scalar), .{ undefined, 2         }, .{ 1,         undefined });
    testInner(@Vector(2, Scalar), .{ undefined, 2         }, .{ undefined, 2         });
    // zig fmt: on
}

/// At the time of writing, this is expected to trigger:
/// * 26 errors if `T` is a float (or vector of floats)
/// * 29 errors if `T` is an int (or vector of ints)
fn testInner(comptime T: type, comptime u: T, comptime maybe_defined: T) void {
    const Scalar = switch (@typeInfo(T)) {
        .float, .int => T,
        .vector => |v| v.child,
        else => unreachable,
    };

    const mode: std.builtin.FloatMode = switch (@typeInfo(Scalar)) {
        .float => .optimized,
        .int => .strict, // it shouldn't matter
        else => unreachable,
    };

    _ = struct {
        const a: T = maybe_defined;
        var b: T = maybe_defined;

        // undef LHS, comptime-known RHS
        comptime {
            @setFloatMode(mode);
            _ = u / a;
        }
        comptime {
            @setFloatMode(mode);
            _ = @divFloor(u, a);
        }
        comptime {
            @setFloatMode(mode);
            _ = @divTrunc(u, a);
        }
        comptime {
            // Don't need to set float mode, because this can be IB anyway
            _ = @divExact(u, a);
        }
        comptime {
            @setFloatMode(mode);
            _ = u % a;
        }
        comptime {
            @setFloatMode(mode);
            _ = @mod(u, a);
        }
        comptime {
            @setFloatMode(mode);
            _ = @rem(u, a);
        }

        // undef LHS, runtime-known RHS
        comptime {
            @setFloatMode(mode);
            _ = u / b;
        }
        comptime {
            @setFloatMode(mode);
            _ = @divFloor(u, b);
        }
        comptime {
            @setFloatMode(mode);
            _ = @divTrunc(u, b);
        }
        comptime {
            // Don't need to set float mode, because this can be IB anyway
            _ = @divExact(u, b);
        }
        comptime {
            @setFloatMode(mode);
            _ = @mod(u, b);
        }
        comptime {
            @setFloatMode(mode);
            _ = @rem(u, b);
        }

        // undef RHS, comptime-known LHS
        comptime {
            @setFloatMode(mode);
            _ = a / u;
        }
        comptime {
            @setFloatMode(mode);
            _ = @divFloor(a, u);
        }
        comptime {
            @setFloatMode(mode);
            _ = @divTrunc(a, u);
        }
        comptime {
            // Don't need to set float mode, because this can be IB anyway
            _ = @divExact(a, u);
        }
        comptime {
            @setFloatMode(mode);
            _ = a % u;
        }
        comptime {
            @setFloatMode(mode);
            _ = @mod(a, u);
        }
        comptime {
            @setFloatMode(mode);
            _ = @rem(a, u);
        }

        // undef RHS, runtime-known LHS
        comptime {
            @setFloatMode(mode);
            _ = b / u;
        }
        comptime {
            @setFloatMode(mode);
            _ = @divFloor(b, u);
        }
        comptime {
            @setFloatMode(mode);
            _ = @divTrunc(b, u);
        }
        comptime {
            // Don't need to set float mode, because this can be IB anyway
            _ = @divExact(b, u);
        }
        comptime {
            @setFloatMode(mode);
            _ = @mod(b, u);
        }
        comptime {
            @setFloatMode(mode);
            _ = @rem(b, u);
        }

        // The following tests should only fail for integer types.

        comptime {
            _ = u + a;
        }
        comptime {
            _ = u - a;
        }
        comptime {
            _ = u * a;
        }
    };
}

const std = @import("std");

// error
//
// :65:17: error: use of undefined value here causes illegal behavior
// :65:17: error: use of undefined value here causes illegal behavior
// :65:17: error: use of undefined value here causes illegal behavior
// :65:17: note: when computing vector element at index '0'
// :65:17: error: use of undefined value here causes illegal behavior
// :65:17: note: when computing vector element at index '0'
// :65:17: error: use of undefined value here causes illegal behavior
// :65:17: note: when computing vector element at index '0'
// :65:17: error: use of undefined value here causes illegal behavior
// :65:17: note: when computing vector element at index '0'
// :65:17: error: use of undefined value here causes illegal behavior
// :65:17: note: when computing vector element at index '1'
// :65:17: error: use of undefined value here causes illegal behavior
// :65:17: note: when computing vector element at index '1'
// :65:17: error: use of undefined value here causes illegal behavior
// :65:17: note: when computing vector element at index '0'
// :65:17: error: use of undefined value here causes illegal behavior
// :65:17: note: when computing vector element at index '0'
// :65:17: error: use of undefined value here causes illegal behavior
// :65:17: note: when computing vector element at index '0'
// :65:17: error: use of undefined value here causes illegal behavior
// :65:17: note: when computing vector element at index '0'
// :65:17: error: use of undefined value here causes illegal behavior
// :65:17: error: use of undefined value here causes illegal behavior
// :65:17: error: use of undefined value here causes illegal behavior
// :65:17: note: when computing vector element at index '0'
// :65:17: error: use of undefined value here causes illegal behavior
// :65:17: note: when computing vector element at index '0'
// :65:17: error: use of undefined value here causes illegal behavior
// :65:17: note: when computing vector element at index '0'
// :65:17: error: use of undefined value here causes illegal behavior
// :65:17: note: when computing vector element at index '0'
// :65:17: error: use of undefined value here causes illegal behavior
// :65:17: note: when computing vector element at index '1'
// :65:17: error: use of undefined value here causes illegal behavior
// :65:17: note: when computing vector element at index '1'
// :65:17: error: use of undefined value here causes illegal behavior
// :65:17: note: when computing vector element at index '0'
// :65:17: error: use of undefined value here causes illegal behavior
// :65:17: note: when computing vector element at index '0'
// :65:17: error: use of undefined value here causes illegal behavior
// :65:17: note: when computing vector element at index '0'
// :65:17: error: use of undefined value here causes illegal behavior
// :65:17: note: when computing vector element at index '0'
// :65:17: error: use of undefined value here causes illegal behavior
// :65:17: error: use of undefined value here causes illegal behavior
// :65:17: error: use of undefined value here causes illegal behavior
// :65:17: note: when computing vector element at index '0'
// :65:17: error: use of undefined value here causes illegal behavior
// :65:17: note: when computing vector element at index '0'
// :65:17: error: use of undefined value here causes illegal behavior
// :65:17: note: when computing vector element at index '0'
// :65:17: error: use of undefined value here causes illegal behavior
// :65:17: note: when computing vector element at index '0'
// :65:17: error: use of undefined value here causes illegal behavior
// :65:17: note: when computing vector element at index '1'
// :65:17: error: use of undefined value here causes illegal behavior
// :65:17: note: when computing vector element at index '1'
// :65:17: error: use of undefined value here causes illegal behavior
// :65:17: note: when computing vector element at index '0'
// :65:17: error: use of undefined value here causes illegal behavior
// :65:17: note: when computing vector element at index '0'
// :65:17: error: use of undefined value here causes illegal behavior
// :65:17: note: when computing vector element at index '0'
// :65:17: error: use of undefined value here causes illegal behavior
// :65:17: note: when computing vector element at index '0'
// :65:17: error: use of undefined value here causes illegal behavior
// :65:17: error: use of undefined value here causes illegal behavior
// :65:17: error: use of undefined value here causes illegal behavior
// :65:17: note: when computing vector element at index '0'
// :65:17: error: use of undefined value here causes illegal behavior
// :65:17: note: when computing vector element at index '0'
// :65:17: error: use of undefined value here causes illegal behavior
// :65:17: note: when computing vector element at index '0'
// :65:17: error: use of undefined value here causes illegal behavior
// :65:17: note: when computing vector element at index '0'
// :65:17: error: use of undefined value here causes illegal behavior
// :65:17: note: when computing vector element at index '1'
// :65:17: error: use of undefined value here causes illegal behavior
// :65:17: note: when computing vector element at index '1'
// :65:17: error: use of undefined value here causes illegal behavior
// :65:17: note: when computing vector element at index '0'
// :65:17: error: use of undefined value here causes illegal behavior
// :65:17: note: when computing vector element at index '0'
// :65:17: error: use of undefined value here causes illegal behavior
// :65:17: note: when computing vector element at index '0'
// :65:17: error: use of undefined value here causes illegal behavior
// :65:17: note: when computing vector element at index '0'
// :65:17: error: use of undefined value here causes illegal behavior
// :65:17: error: use of undefined value here causes illegal behavior
// :65:17: error: use of undefined value here causes illegal behavior
// :65:17: note: when computing vector element at index '0'
// :65:17: error: use of undefined value here causes illegal behavior
// :65:17: note: when computing vector element at index '0'
// :65:17: error: use of undefined value here causes illegal behavior
// :65:17: note: when computing vector element at index '0'
// :65:17: error: use of undefined value here causes illegal behavior
// :65:17: note: when computing vector element at index '0'
// :65:17: error: use of undefined value here causes illegal behavior
// :65:17: note: when computing vector element at index '1'
// :65:17: error: use of undefined value here causes illegal behavior
// :65:17: note: when computing vector element at index '1'
// :65:17: error: use of undefined value here causes illegal behavior
// :65:17: note: when computing vector element at index '0'
// :65:17: error: use of undefined value here causes illegal behavior
// :65:17: note: when computing vector element at index '0'
// :65:17: error: use of undefined value here causes illegal behavior
// :65:17: note: when computing vector element at index '0'
// :65:17: error: use of undefined value here causes illegal behavior
// :65:17: note: when computing vector element at index '0'
// :65:17: error: use of undefined value here causes illegal behavior
// :65:17: error: use of undefined value here causes illegal behavior
// :65:17: error: use of undefined value here causes illegal behavior
// :65:17: note: when computing vector element at index '0'
// :65:17: error: use of undefined value here causes illegal behavior
// :65:17: note: when computing vector element at index '0'
// :65:17: error: use of undefined value here causes illegal behavior
// :65:17: note: when computing vector element at index '0'
// :65:17: error: use of undefined value here causes illegal behavior
// :65:17: note: when computing vector element at index '0'
// :65:17: error: use of undefined value here causes illegal behavior
// :65:17: note: when computing vector element at index '1'
// :65:17: error: use of undefined value here causes illegal behavior
// :65:17: note: when computing vector element at index '1'
// :65:17: error: use of undefined value here causes illegal behavior
// :65:17: note: when computing vector element at index '0'
// :65:17: error: use of undefined value here causes illegal behavior
// :65:17: note: when computing vector element at index '0'
// :65:17: error: use of undefined value here causes illegal behavior
// :65:17: note: when computing vector element at index '0'
// :65:17: error: use of undefined value here causes illegal behavior
// :65:17: note: when computing vector element at index '0'
// :65:17: error: use of undefined value here causes illegal behavior
// :65:17: error: use of undefined value here causes illegal behavior
// :65:17: error: use of undefined value here causes illegal behavior
// :65:17: note: when computing vector element at index '0'
// :65:17: error: use of undefined value here causes illegal behavior
// :65:17: note: when computing vector element at index '0'
// :65:17: error: use of undefined value here causes illegal behavior
// :65:17: note: when computing vector element at index '0'
// :65:17: error: use of undefined value here causes illegal behavior
// :65:17: note: when computing vector element at index '0'
// :65:17: error: use of undefined value here causes illegal behavior
// :65:17: note: when computing vector element at index '1'
// :65:17: error: use of undefined value here causes illegal behavior
// :65:17: note: when computing vector element at index '1'
// :65:17: error: use of undefined value here causes illegal behavior
// :65:17: note: when computing vector element at index '0'
// :65:17: error: use of undefined value here causes illegal behavior
// :65:17: note: when computing vector element at index '0'
// :65:17: error: use of undefined value here causes illegal behavior
// :65:17: note: when computing vector element at index '0'
// :65:17: error: use of undefined value here causes illegal behavior
// :65:17: note: when computing vector element at index '0'
// :65:17: error: use of undefined value here causes illegal behavior
// :65:17: error: use of undefined value here causes illegal behavior
// :65:17: error: use of undefined value here causes illegal behavior
// :65:17: note: when computing vector element at index '0'
// :65:17: error: use of undefined value here causes illegal behavior
// :65:17: note: when computing vector element at index '0'
// :65:17: error: use of undefined value here causes illegal behavior
// :65:17: note: when computing vector element at index '0'
// :65:17: error: use of undefined value here causes illegal behavior
// :65:17: note: when computing vector element at index '0'
// :65:17: error: use of undefined value here causes illegal behavior
// :65:17: note: when computing vector element at index '1'
// :65:17: error: use of undefined value here causes illegal behavior
// :65:17: note: when computing vector element at index '1'
// :65:17: error: use of undefined value here causes illegal behavior
// :65:17: note: when computing vector element at index '0'
// :65:17: error: use of undefined value here causes illegal behavior
// :65:17: note: when computing vector element at index '0'
// :65:17: error: use of undefined value here causes illegal behavior
// :65:17: note: when computing vector element at index '0'
// :65:17: error: use of undefined value here causes illegal behavior
// :65:17: note: when computing vector element at index '0'
// :65:17: error: use of undefined value here causes illegal behavior
// :65:17: error: use of undefined value here causes illegal behavior
// :65:17: error: use of undefined value here causes illegal behavior
// :65:17: note: when computing vector element at index '0'
// :65:17: error: use of undefined value here causes illegal behavior
// :65:17: note: when computing vector element at index '0'
// :65:17: error: use of undefined value here causes illegal behavior
// :65:17: note: when computing vector element at index '0'
// :65:17: error: use of undefined value here causes illegal behavior
// :65:17: note: when computing vector element at index '0'
// :65:17: error: use of undefined value here causes illegal behavior
// :65:17: note: when computing vector element at index '1'
// :65:17: error: use of undefined value here causes illegal behavior
// :65:17: note: when computing vector element at index '1'
// :65:17: error: use of undefined value here causes illegal behavior
// :65:17: note: when computing vector element at index '0'
// :65:17: error: use of undefined value here causes illegal behavior
// :65:17: note: when computing vector element at index '0'
// :65:17: error: use of undefined value here causes illegal behavior
// :65:17: note: when computing vector element at index '0'
// :65:17: error: use of undefined value here causes illegal behavior
// :65:17: note: when computing vector element at index '0'
// :65:17: error: use of undefined value here causes illegal behavior
// :65:17: error: use of undefined value here causes illegal behavior
// :65:17: error: use of undefined value here causes illegal behavior
// :65:17: note: when computing vector element at index '0'
// :65:17: error: use of undefined value here causes illegal behavior
// :65:17: note: when computing vector element at index '0'
// :65:17: error: use of undefined value here causes illegal behavior
// :65:17: note: when computing vector element at index '0'
// :65:17: error: use of undefined value here causes illegal behavior
// :65:17: note: when computing vector element at index '0'
// :65:17: error: use of undefined value here causes illegal behavior
// :65:17: note: when computing vector element at index '1'
// :65:17: error: use of undefined value here causes illegal behavior
// :65:17: note: when computing vector element at index '1'
// :65:17: error: use of undefined value here causes illegal behavior
// :65:17: note: when computing vector element at index '0'
// :65:17: error: use of undefined value here causes illegal behavior
// :65:17: note: when computing vector element at index '0'
// :65:17: error: use of undefined value here causes illegal behavior
// :65:17: note: when computing vector element at index '0'
// :65:17: error: use of undefined value here causes illegal behavior
// :65:17: note: when computing vector element at index '0'
// :65:17: error: use of undefined value here causes illegal behavior
// :65:17: error: use of undefined value here causes illegal behavior
// :65:17: error: use of undefined value here causes illegal behavior
// :65:17: note: when computing vector element at index '0'
// :65:17: error: use of undefined value here causes illegal behavior
// :65:17: note: when computing vector element at index '0'
// :65:17: error: use of undefined value here causes illegal behavior
// :65:17: note: when computing vector element at index '0'
// :65:17: error: use of undefined value here causes illegal behavior
// :65:17: note: when computing vector element at index '0'
// :65:17: error: use of undefined value here causes illegal behavior
// :65:17: note: when computing vector element at index '1'
// :65:17: error: use of undefined value here causes illegal behavior
// :65:17: note: when computing vector element at index '1'
// :65:17: error: use of undefined value here causes illegal behavior
// :65:17: note: when computing vector element at index '0'
// :65:17: error: use of undefined value here causes illegal behavior
// :65:17: note: when computing vector element at index '0'
// :65:17: error: use of undefined value here causes illegal behavior
// :65:17: note: when computing vector element at index '0'
// :65:17: error: use of undefined value here causes illegal behavior
// :65:17: note: when computing vector element at index '0'
// :65:21: error: use of undefined value here causes illegal behavior
// :65:21: note: when computing vector element at index '0'
// :65:21: error: use of undefined value here causes illegal behavior
// :65:21: note: when computing vector element at index '0'
// :65:21: error: use of undefined value here causes illegal behavior
// :65:21: note: when computing vector element at index '0'
// :65:21: error: use of undefined value here causes illegal behavior
// :65:21: note: when computing vector element at index '0'
// :65:21: error: use of undefined value here causes illegal behavior
// :65:21: note: when computing vector element at index '0'
// :65:21: error: use of undefined value here causes illegal behavior
// :65:21: note: when computing vector element at index '0'
// :65:21: error: use of undefined value here causes illegal behavior
// :65:21: note: when computing vector element at index '0'
// :65:21: error: use of undefined value here causes illegal behavior
// :65:21: note: when computing vector element at index '0'
// :65:21: error: use of undefined value here causes illegal behavior
// :65:21: note: when computing vector element at index '0'
// :65:21: error: use of undefined value here causes illegal behavior
// :65:21: note: when computing vector element at index '0'
// :65:21: error: use of undefined value here causes illegal behavior
// :65:21: note: when computing vector element at index '0'
// :65:21: error: use of undefined value here causes illegal behavior
// :65:21: note: when computing vector element at index '0'
// :65:21: error: use of undefined value here causes illegal behavior
// :65:21: note: when computing vector element at index '0'
// :65:21: error: use of undefined value here causes illegal behavior
// :65:21: note: when computing vector element at index '0'
// :65:21: error: use of undefined value here causes illegal behavior
// :65:21: note: when computing vector element at index '0'
// :65:21: error: use of undefined value here causes illegal behavior
// :65:21: note: when computing vector element at index '0'
// :65:21: error: use of undefined value here causes illegal behavior
// :65:21: note: when computing vector element at index '0'
// :65:21: error: use of undefined value here causes illegal behavior
// :65:21: note: when computing vector element at index '0'
// :65:21: error: use of undefined value here causes illegal behavior
// :65:21: note: when computing vector element at index '0'
// :65:21: error: use of undefined value here causes illegal behavior
// :65:21: note: when computing vector element at index '0'
// :65:21: error: use of undefined value here causes illegal behavior
// :65:21: note: when computing vector element at index '0'
// :65:21: error: use of undefined value here causes illegal behavior
// :65:21: note: when computing vector element at index '0'
// :69:27: error: use of undefined value here causes illegal behavior
// :69:27: error: use of undefined value here causes illegal behavior
// :69:27: error: use of undefined value here causes illegal behavior
// :69:27: note: when computing vector element at index '0'
// :69:27: error: use of undefined value here causes illegal behavior
// :69:27: note: when computing vector element at index '0'
// :69:27: error: use of undefined value here causes illegal behavior
// :69:27: note: when computing vector element at index '0'
// :69:27: error: use of undefined value here causes illegal behavior
// :69:27: note: when computing vector element at index '0'
// :69:27: error: use of undefined value here causes illegal behavior
// :69:27: note: when computing vector element at index '1'
// :69:27: error: use of undefined value here causes illegal behavior
// :69:27: note: when computing vector element at index '1'
// :69:27: error: use of undefined value here causes illegal behavior
// :69:27: note: when computing vector element at index '0'
// :69:27: error: use of undefined value here causes illegal behavior
// :69:27: note: when computing vector element at index '0'
// :69:27: error: use of undefined value here causes illegal behavior
// :69:27: note: when computing vector element at index '0'
// :69:27: error: use of undefined value here causes illegal behavior
// :69:27: note: when computing vector element at index '0'
// :69:27: error: use of undefined value here causes illegal behavior
// :69:27: error: use of undefined value here causes illegal behavior
// :69:27: error: use of undefined value here causes illegal behavior
// :69:27: note: when computing vector element at index '0'
// :69:27: error: use of undefined value here causes illegal behavior
// :69:27: note: when computing vector element at index '0'
// :69:27: error: use of undefined value here causes illegal behavior
// :69:27: note: when computing vector element at index '0'
// :69:27: error: use of undefined value here causes illegal behavior
// :69:27: note: when computing vector element at index '0'
// :69:27: error: use of undefined value here causes illegal behavior
// :69:27: note: when computing vector element at index '1'
// :69:27: error: use of undefined value here causes illegal behavior
// :69:27: note: when computing vector element at index '1'
// :69:27: error: use of undefined value here causes illegal behavior
// :69:27: note: when computing vector element at index '0'
// :69:27: error: use of undefined value here causes illegal behavior
// :69:27: note: when computing vector element at index '0'
// :69:27: error: use of undefined value here causes illegal behavior
// :69:27: note: when computing vector element at index '0'
// :69:27: error: use of undefined value here causes illegal behavior
// :69:27: note: when computing vector element at index '0'
// :69:27: error: use of undefined value here causes illegal behavior
// :69:27: error: use of undefined value here causes illegal behavior
// :69:27: error: use of undefined value here causes illegal behavior
// :69:27: note: when computing vector element at index '0'
// :69:27: error: use of undefined value here causes illegal behavior
// :69:27: note: when computing vector element at index '0'
// :69:27: error: use of undefined value here causes illegal behavior
// :69:27: note: when computing vector element at index '0'
// :69:27: error: use of undefined value here causes illegal behavior
// :69:27: note: when computing vector element at index '0'
// :69:27: error: use of undefined value here causes illegal behavior
// :69:27: note: when computing vector element at index '1'
// :69:27: error: use of undefined value here causes illegal behavior
// :69:27: note: when computing vector element at index '1'
// :69:27: error: use of undefined value here causes illegal behavior
// :69:27: note: when computing vector element at index '0'
// :69:27: error: use of undefined value here causes illegal behavior
// :69:27: note: when computing vector element at index '0'
// :69:27: error: use of undefined value here causes illegal behavior
// :69:27: note: when computing vector element at index '0'
// :69:27: error: use of undefined value here causes illegal behavior
// :69:27: note: when computing vector element at index '0'
// :69:27: error: use of undefined value here causes illegal behavior
// :69:27: error: use of undefined value here causes illegal behavior
// :69:27: error: use of undefined value here causes illegal behavior
// :69:27: note: when computing vector element at index '0'
// :69:27: error: use of undefined value here causes illegal behavior
// :69:27: note: when computing vector element at index '0'
// :69:27: error: use of undefined value here causes illegal behavior
// :69:27: note: when computing vector element at index '0'
// :69:27: error: use of undefined value here causes illegal behavior
// :69:27: note: when computing vector element at index '0'
// :69:27: error: use of undefined value here causes illegal behavior
// :69:27: note: when computing vector element at index '1'
// :69:27: error: use of undefined value here causes illegal behavior
// :69:27: note: when computing vector element at index '1'
// :69:27: error: use of undefined value here causes illegal behavior
// :69:27: note: when computing vector element at index '0'
// :69:27: error: use of undefined value here causes illegal behavior
// :69:27: note: when computing vector element at index '0'
// :69:27: error: use of undefined value here causes illegal behavior
// :69:27: note: when computing vector element at index '0'
// :69:27: error: use of undefined value here causes illegal behavior
// :69:27: note: when computing vector element at index '0'
// :69:27: error: use of undefined value here causes illegal behavior
// :69:27: error: use of undefined value here causes illegal behavior
// :69:27: error: use of undefined value here causes illegal behavior
// :69:27: note: when computing vector element at index '0'
// :69:27: error: use of undefined value here causes illegal behavior
// :69:27: note: when computing vector element at index '0'
// :69:27: error: use of undefined value here causes illegal behavior
// :69:27: note: when computing vector element at index '0'
// :69:27: error: use of undefined value here causes illegal behavior
// :69:27: note: when computing vector element at index '0'
// :69:27: error: use of undefined value here causes illegal behavior
// :69:27: note: when computing vector element at index '1'
// :69:27: error: use of undefined value here causes illegal behavior
// :69:27: note: when computing vector element at index '1'
// :69:27: error: use of undefined value here causes illegal behavior
// :69:27: note: when computing vector element at index '0'
// :69:27: error: use of undefined value here causes illegal behavior
// :69:27: note: when computing vector element at index '0'
// :69:27: error: use of undefined value here causes illegal behavior
// :69:27: note: when computing vector element at index '0'
// :69:27: error: use of undefined value here causes illegal behavior
// :69:27: note: when computing vector element at index '0'
// :69:27: error: use of undefined value here causes illegal behavior
// :69:27: error: use of undefined value here causes illegal behavior
// :69:27: error: use of undefined value here causes illegal behavior
// :69:27: note: when computing vector element at index '0'
// :69:27: error: use of undefined value here causes illegal behavior
// :69:27: note: when computing vector element at index '0'
// :69:27: error: use of undefined value here causes illegal behavior
// :69:27: note: when computing vector element at index '0'
// :69:27: error: use of undefined value here causes illegal behavior
// :69:27: note: when computing vector element at index '0'
// :69:27: error: use of undefined value here causes illegal behavior
// :69:27: note: when computing vector element at index '1'
// :69:27: error: use of undefined value here causes illegal behavior
// :69:27: note: when computing vector element at index '1'
// :69:27: error: use of undefined value here causes illegal behavior
// :69:27: note: when computing vector element at index '0'
// :69:27: error: use of undefined value here causes illegal behavior
// :69:27: note: when computing vector element at index '0'
// :69:27: error: use of undefined value here causes illegal behavior
// :69:27: note: when computing vector element at index '0'
// :69:27: error: use of undefined value here causes illegal behavior
// :69:27: note: when computing vector element at index '0'
// :69:27: error: use of undefined value here causes illegal behavior
// :69:27: error: use of undefined value here causes illegal behavior
// :69:27: error: use of undefined value here causes illegal behavior
// :69:27: note: when computing vector element at index '0'
// :69:27: error: use of undefined value here causes illegal behavior
// :69:27: note: when computing vector element at index '0'
// :69:27: error: use of undefined value here causes illegal behavior
// :69:27: note: when computing vector element at index '0'
// :69:27: error: use of undefined value here causes illegal behavior
// :69:27: note: when computing vector element at index '0'
// :69:27: error: use of undefined value here causes illegal behavior
// :69:27: note: when computing vector element at index '1'
// :69:27: error: use of undefined value here causes illegal behavior
// :69:27: note: when computing vector element at index '1'
// :69:27: error: use of undefined value here causes illegal behavior
// :69:27: note: when computing vector element at index '0'
// :69:27: error: use of undefined value here causes illegal behavior
// :69:27: note: when computing vector element at index '0'
// :69:27: error: use of undefined value here causes illegal behavior
// :69:27: note: when computing vector element at index '0'
// :69:27: error: use of undefined value here causes illegal behavior
// :69:27: note: when computing vector element at index '0'
// :69:27: error: use of undefined value here causes illegal behavior
// :69:27: error: use of undefined value here causes illegal behavior
// :69:27: error: use of undefined value here causes illegal behavior
// :69:27: note: when computing vector element at index '0'
// :69:27: error: use of undefined value here causes illegal behavior
// :69:27: note: when computing vector element at index '0'
// :69:27: error: use of undefined value here causes illegal behavior
// :69:27: note: when computing vector element at index '0'
// :69:27: error: use of undefined value here causes illegal behavior
// :69:27: note: when computing vector element at index '0'
// :69:27: error: use of undefined value here causes illegal behavior
// :69:27: note: when computing vector element at index '1'
// :69:27: error: use of undefined value here causes illegal behavior
// :69:27: note: when computing vector element at index '1'
// :69:27: error: use of undefined value here causes illegal behavior
// :69:27: note: when computing vector element at index '0'
// :69:27: error: use of undefined value here causes illegal behavior
// :69:27: note: when computing vector element at index '0'
// :69:27: error: use of undefined value here causes illegal behavior
// :69:27: note: when computing vector element at index '0'
// :69:27: error: use of undefined value here causes illegal behavior
// :69:27: note: when computing vector element at index '0'
// :69:27: error: use of undefined value here causes illegal behavior
// :69:27: error: use of undefined value here causes illegal behavior
// :69:27: error: use of undefined value here causes illegal behavior
// :69:27: note: when computing vector element at index '0'
// :69:27: error: use of undefined value here causes illegal behavior
// :69:27: note: when computing vector element at index '0'
// :69:27: error: use of undefined value here causes illegal behavior
// :69:27: note: when computing vector element at index '0'
// :69:27: error: use of undefined value here causes illegal behavior
// :69:27: note: when computing vector element at index '0'
// :69:27: error: use of undefined value here causes illegal behavior
// :69:27: note: when computing vector element at index '1'
// :69:27: error: use of undefined value here causes illegal behavior
// :69:27: note: when computing vector element at index '1'
// :69:27: error: use of undefined value here causes illegal behavior
// :69:27: note: when computing vector element at index '0'
// :69:27: error: use of undefined value here causes illegal behavior
// :69:27: note: when computing vector element at index '0'
// :69:27: error: use of undefined value here causes illegal behavior
// :69:27: note: when computing vector element at index '0'
// :69:27: error: use of undefined value here causes illegal behavior
// :69:27: note: when computing vector element at index '0'
// :69:27: error: use of undefined value here causes illegal behavior
// :69:27: error: use of undefined value here causes illegal behavior
// :69:27: error: use of undefined value here causes illegal behavior
// :69:27: note: when computing vector element at index '0'
// :69:27: error: use of undefined value here causes illegal behavior
// :69:27: note: when computing vector element at index '0'
// :69:27: error: use of undefined value here causes illegal behavior
// :69:27: note: when computing vector element at index '0'
// :69:27: error: use of undefined value here causes illegal behavior
// :69:27: note: when computing vector element at index '0'
// :69:27: error: use of undefined value here causes illegal behavior
// :69:27: note: when computing vector element at index '1'
// :69:27: error: use of undefined value here causes illegal behavior
// :69:27: note: when computing vector element at index '1'
// :69:27: error: use of undefined value here causes illegal behavior
// :69:27: note: when computing vector element at index '0'
// :69:27: error: use of undefined value here causes illegal behavior
// :69:27: note: when computing vector element at index '0'
// :69:27: error: use of undefined value here causes illegal behavior
// :69:27: note: when computing vector element at index '0'
// :69:27: error: use of undefined value here causes illegal behavior
// :69:27: note: when computing vector element at index '0'
// :69:27: error: use of undefined value here causes illegal behavior
// :69:27: error: use of undefined value here causes illegal behavior
// :69:27: error: use of undefined value here causes illegal behavior
// :69:27: note: when computing vector element at index '0'
// :69:27: error: use of undefined value here causes illegal behavior
// :69:27: note: when computing vector element at index '0'
// :69:27: error: use of undefined value here causes illegal behavior
// :69:27: note: when computing vector element at index '0'
// :69:27: error: use of undefined value here causes illegal behavior
// :69:27: note: when computing vector element at index '0'
// :69:27: error: use of undefined value here causes illegal behavior
// :69:27: note: when computing vector element at index '1'
// :69:27: error: use of undefined value here causes illegal behavior
// :69:27: note: when computing vector element at index '1'
// :69:27: error: use of undefined value here causes illegal behavior
// :69:27: note: when computing vector element at index '0'
// :69:27: error: use of undefined value here causes illegal behavior
// :69:27: note: when computing vector element at index '0'
// :69:27: error: use of undefined value here causes illegal behavior
// :69:27: note: when computing vector element at index '0'
// :69:27: error: use of undefined value here causes illegal behavior
// :69:27: note: when computing vector element at index '0'
// :69:30: error: use of undefined value here causes illegal behavior
// :69:30: note: when computing vector element at index '0'
// :69:30: error: use of undefined value here causes illegal behavior
// :69:30: note: when computing vector element at index '0'
// :69:30: error: use of undefined value here causes illegal behavior
// :69:30: note: when computing vector element at index '0'
// :69:30: error: use of undefined value here causes illegal behavior
// :69:30: note: when computing vector element at index '0'
// :69:30: error: use of undefined value here causes illegal behavior
// :69:30: note: when computing vector element at index '0'
// :69:30: error: use of undefined value here causes illegal behavior
// :69:30: note: when computing vector element at index '0'
// :69:30: error: use of undefined value here causes illegal behavior
// :69:30: note: when computing vector element at index '0'
// :69:30: error: use of undefined value here causes illegal behavior
// :69:30: note: when computing vector element at index '0'
// :69:30: error: use of undefined value here causes illegal behavior
// :69:30: note: when computing vector element at index '0'
// :69:30: error: use of undefined value here causes illegal behavior
// :69:30: note: when computing vector element at index '0'
// :69:30: error: use of undefined value here causes illegal behavior
// :69:30: note: when computing vector element at index '0'
// :69:30: error: use of undefined value here causes illegal behavior
// :69:30: note: when computing vector element at index '0'
// :69:30: error: use of undefined value here causes illegal behavior
// :69:30: note: when computing vector element at index '0'
// :69:30: error: use of undefined value here causes illegal behavior
// :69:30: note: when computing vector element at index '0'
// :69:30: error: use of undefined value here causes illegal behavior
// :69:30: note: when computing vector element at index '0'
// :69:30: error: use of undefined value here causes illegal behavior
// :69:30: note: when computing vector element at index '0'
// :69:30: error: use of undefined value here causes illegal behavior
// :69:30: note: when computing vector element at index '0'
// :69:30: error: use of undefined value here causes illegal behavior
// :69:30: note: when computing vector element at index '0'
// :69:30: error: use of undefined value here causes illegal behavior
// :69:30: note: when computing vector element at index '0'
// :69:30: error: use of undefined value here causes illegal behavior
// :69:30: note: when computing vector element at index '0'
// :69:30: error: use of undefined value here causes illegal behavior
// :69:30: note: when computing vector element at index '0'
// :69:30: error: use of undefined value here causes illegal behavior
// :69:30: note: when computing vector element at index '0'
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: note: when computing vector element at index '0'
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: note: when computing vector element at index '0'
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: note: when computing vector element at index '0'
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: note: when computing vector element at index '0'
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: note: when computing vector element at index '1'
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: note: when computing vector element at index '1'
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: note: when computing vector element at index '0'
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: note: when computing vector element at index '0'
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: note: when computing vector element at index '0'
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: note: when computing vector element at index '0'
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: note: when computing vector element at index '0'
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: note: when computing vector element at index '0'
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: note: when computing vector element at index '0'
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: note: when computing vector element at index '0'
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: note: when computing vector element at index '1'
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: note: when computing vector element at index '1'
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: note: when computing vector element at index '0'
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: note: when computing vector element at index '0'
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: note: when computing vector element at index '0'
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: note: when computing vector element at index '0'
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: note: when computing vector element at index '0'
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: note: when computing vector element at index '0'
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: note: when computing vector element at index '0'
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: note: when computing vector element at index '0'
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: note: when computing vector element at index '1'
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: note: when computing vector element at index '1'
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: note: when computing vector element at index '0'
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: note: when computing vector element at index '0'
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: note: when computing vector element at index '0'
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: note: when computing vector element at index '0'
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: note: when computing vector element at index '0'
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: note: when computing vector element at index '0'
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: note: when computing vector element at index '0'
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: note: when computing vector element at index '0'
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: note: when computing vector element at index '1'
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: note: when computing vector element at index '1'
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: note: when computing vector element at index '0'
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: note: when computing vector element at index '0'
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: note: when computing vector element at index '0'
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: note: when computing vector element at index '0'
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: note: when computing vector element at index '0'
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: note: when computing vector element at index '0'
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: note: when computing vector element at index '0'
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: note: when computing vector element at index '0'
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: note: when computing vector element at index '1'
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: note: when computing vector element at index '1'
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: note: when computing vector element at index '0'
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: note: when computing vector element at index '0'
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: note: when computing vector element at index '0'
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: note: when computing vector element at index '0'
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: note: when computing vector element at index '0'
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: note: when computing vector element at index '0'
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: note: when computing vector element at index '0'
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: note: when computing vector element at index '0'
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: note: when computing vector element at index '1'
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: note: when computing vector element at index '1'
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: note: when computing vector element at index '0'
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: note: when computing vector element at index '0'
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: note: when computing vector element at index '0'
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: note: when computing vector element at index '0'
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: note: when computing vector element at index '0'
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: note: when computing vector element at index '0'
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: note: when computing vector element at index '0'
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: note: when computing vector element at index '0'
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: note: when computing vector element at index '1'
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: note: when computing vector element at index '1'
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: note: when computing vector element at index '0'
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: note: when computing vector element at index '0'
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: note: when computing vector element at index '0'
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: note: when computing vector element at index '0'
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: note: when computing vector element at index '0'
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: note: when computing vector element at index '0'
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: note: when computing vector element at index '0'
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: note: when computing vector element at index '0'
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: note: when computing vector element at index '1'
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: note: when computing vector element at index '1'
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: note: when computing vector element at index '0'
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: note: when computing vector element at index '0'
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: note: when computing vector element at index '0'
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: note: when computing vector element at index '0'
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: note: when computing vector element at index '0'
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: note: when computing vector element at index '0'
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: note: when computing vector element at index '0'
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: note: when computing vector element at index '0'
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: note: when computing vector element at index '1'
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: note: when computing vector element at index '1'
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: note: when computing vector element at index '0'
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: note: when computing vector element at index '0'
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: note: when computing vector element at index '0'
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: note: when computing vector element at index '0'
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: note: when computing vector element at index '0'
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: note: when computing vector element at index '0'
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: note: when computing vector element at index '0'
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: note: when computing vector element at index '0'
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: note: when computing vector element at index '1'
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: note: when computing vector element at index '1'
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: note: when computing vector element at index '0'
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: note: when computing vector element at index '0'
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: note: when computing vector element at index '0'
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: note: when computing vector element at index '0'
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: note: when computing vector element at index '0'
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: note: when computing vector element at index '0'
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: note: when computing vector element at index '0'
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: note: when computing vector element at index '0'
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: note: when computing vector element at index '1'
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: note: when computing vector element at index '1'
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: note: when computing vector element at index '0'
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: note: when computing vector element at index '0'
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: note: when computing vector element at index '0'
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: note: when computing vector element at index '0'
// :73:30: error: use of undefined value here causes illegal behavior
// :73:30: note: when computing vector element at index '0'
// :73:30: error: use of undefined value here causes illegal behavior
// :73:30: note: when computing vector element at index '0'
// :73:30: error: use of undefined value here causes illegal behavior
// :73:30: note: when computing vector element at index '0'
// :73:30: error: use of undefined value here causes illegal behavior
// :73:30: note: when computing vector element at index '0'
// :73:30: error: use of undefined value here causes illegal behavior
// :73:30: note: when computing vector element at index '0'
// :73:30: error: use of undefined value here causes illegal behavior
// :73:30: note: when computing vector element at index '0'
// :73:30: error: use of undefined value here causes illegal behavior
// :73:30: note: when computing vector element at index '0'
// :73:30: error: use of undefined value here causes illegal behavior
// :73:30: note: when computing vector element at index '0'
// :73:30: error: use of undefined value here causes illegal behavior
// :73:30: note: when computing vector element at index '0'
// :73:30: error: use of undefined value here causes illegal behavior
// :73:30: note: when computing vector element at index '0'
// :73:30: error: use of undefined value here causes illegal behavior
// :73:30: note: when computing vector element at index '0'
// :73:30: error: use of undefined value here causes illegal behavior
// :73:30: note: when computing vector element at index '0'
// :73:30: error: use of undefined value here causes illegal behavior
// :73:30: note: when computing vector element at index '0'
// :73:30: error: use of undefined value here causes illegal behavior
// :73:30: note: when computing vector element at index '0'
// :73:30: error: use of undefined value here causes illegal behavior
// :73:30: note: when computing vector element at index '0'
// :73:30: error: use of undefined value here causes illegal behavior
// :73:30: note: when computing vector element at index '0'
// :73:30: error: use of undefined value here causes illegal behavior
// :73:30: note: when computing vector element at index '0'
// :73:30: error: use of undefined value here causes illegal behavior
// :73:30: note: when computing vector element at index '0'
// :73:30: error: use of undefined value here causes illegal behavior
// :73:30: note: when computing vector element at index '0'
// :73:30: error: use of undefined value here causes illegal behavior
// :73:30: note: when computing vector element at index '0'
// :73:30: error: use of undefined value here causes illegal behavior
// :73:30: note: when computing vector element at index '0'
// :73:30: error: use of undefined value here causes illegal behavior
// :73:30: note: when computing vector element at index '0'
// :77:27: error: use of undefined value here causes illegal behavior
// :77:27: error: use of undefined value here causes illegal behavior
// :77:27: error: use of undefined value here causes illegal behavior
// :77:27: note: when computing vector element at index '0'
// :77:27: error: use of undefined value here causes illegal behavior
// :77:27: note: when computing vector element at index '0'
// :77:27: error: use of undefined value here causes illegal behavior
// :77:27: note: when computing vector element at index '0'
// :77:27: error: use of undefined value here causes illegal behavior
// :77:27: note: when computing vector element at index '0'
// :77:27: error: use of undefined value here causes illegal behavior
// :77:27: note: when computing vector element at index '1'
// :77:27: error: use of undefined value here causes illegal behavior
// :77:27: note: when computing vector element at index '1'
// :77:27: error: use of undefined value here causes illegal behavior
// :77:27: note: when computing vector element at index '0'
// :77:27: error: use of undefined value here causes illegal behavior
// :77:27: note: when computing vector element at index '0'
// :77:27: error: use of undefined value here causes illegal behavior
// :77:27: note: when computing vector element at index '0'
// :77:27: error: use of undefined value here causes illegal behavior
// :77:27: note: when computing vector element at index '0'
// :77:27: error: use of undefined value here causes illegal behavior
// :77:27: error: use of undefined value here causes illegal behavior
// :77:27: error: use of undefined value here causes illegal behavior
// :77:27: note: when computing vector element at index '0'
// :77:27: error: use of undefined value here causes illegal behavior
// :77:27: note: when computing vector element at index '0'
// :77:27: error: use of undefined value here causes illegal behavior
// :77:27: note: when computing vector element at index '0'
// :77:27: error: use of undefined value here causes illegal behavior
// :77:27: note: when computing vector element at index '0'
// :77:27: error: use of undefined value here causes illegal behavior
// :77:27: note: when computing vector element at index '1'
// :77:27: error: use of undefined value here causes illegal behavior
// :77:27: note: when computing vector element at index '1'
// :77:27: error: use of undefined value here causes illegal behavior
// :77:27: note: when computing vector element at index '0'
// :77:27: error: use of undefined value here causes illegal behavior
// :77:27: note: when computing vector element at index '0'
// :77:27: error: use of undefined value here causes illegal behavior
// :77:27: note: when computing vector element at index '0'
// :77:27: error: use of undefined value here causes illegal behavior
// :77:27: note: when computing vector element at index '0'
// :77:27: error: use of undefined value here causes illegal behavior
// :77:27: error: use of undefined value here causes illegal behavior
// :77:27: error: use of undefined value here causes illegal behavior
// :77:27: note: when computing vector element at index '0'
// :77:27: error: use of undefined value here causes illegal behavior
// :77:27: note: when computing vector element at index '0'
// :77:27: error: use of undefined value here causes illegal behavior
// :77:27: note: when computing vector element at index '0'
// :77:27: error: use of undefined value here causes illegal behavior
// :77:27: note: when computing vector element at index '0'
// :77:27: error: use of undefined value here causes illegal behavior
// :77:27: note: when computing vector element at index '1'
// :77:27: error: use of undefined value here causes illegal behavior
// :77:27: note: when computing vector element at index '1'
// :77:27: error: use of undefined value here causes illegal behavior
// :77:27: note: when computing vector element at index '0'
// :77:27: error: use of undefined value here causes illegal behavior
// :77:27: note: when computing vector element at index '0'
// :77:27: error: use of undefined value here causes illegal behavior
// :77:27: note: when computing vector element at index '0'
// :77:27: error: use of undefined value here causes illegal behavior
// :77:27: note: when computing vector element at index '0'
// :77:27: error: use of undefined value here causes illegal behavior
// :77:27: error: use of undefined value here causes illegal behavior
// :77:27: error: use of undefined value here causes illegal behavior
// :77:27: note: when computing vector element at index '0'
// :77:27: error: use of undefined value here causes illegal behavior
// :77:27: note: when computing vector element at index '0'
// :77:27: error: use of undefined value here causes illegal behavior
// :77:27: note: when computing vector element at index '0'
// :77:27: error: use of undefined value here causes illegal behavior
// :77:27: note: when computing vector element at index '0'
// :77:27: error: use of undefined value here causes illegal behavior
// :77:27: note: when computing vector element at index '1'
// :77:27: error: use of undefined value here causes illegal behavior
// :77:27: note: when computing vector element at index '1'
// :77:27: error: use of undefined value here causes illegal behavior
// :77:27: note: when computing vector element at index '0'
// :77:27: error: use of undefined value here causes illegal behavior
// :77:27: note: when computing vector element at index '0'
// :77:27: error: use of undefined value here causes illegal behavior
// :77:27: note: when computing vector element at index '0'
// :77:27: error: use of undefined value here causes illegal behavior
// :77:27: note: when computing vector element at index '0'
// :77:27: error: use of undefined value here causes illegal behavior
// :77:27: error: use of undefined value here causes illegal behavior
// :77:27: error: use of undefined value here causes illegal behavior
// :77:27: note: when computing vector element at index '0'
// :77:27: error: use of undefined value here causes illegal behavior
// :77:27: note: when computing vector element at index '0'
// :77:27: error: use of undefined value here causes illegal behavior
// :77:27: note: when computing vector element at index '0'
// :77:27: error: use of undefined value here causes illegal behavior
// :77:27: note: when computing vector element at index '0'
// :77:27: error: use of undefined value here causes illegal behavior
// :77:27: note: when computing vector element at index '1'
// :77:27: error: use of undefined value here causes illegal behavior
// :77:27: note: when computing vector element at index '1'
// :77:27: error: use of undefined value here causes illegal behavior
// :77:27: note: when computing vector element at index '0'
// :77:27: error: use of undefined value here causes illegal behavior
// :77:27: note: when computing vector element at index '0'
// :77:27: error: use of undefined value here causes illegal behavior
// :77:27: note: when computing vector element at index '0'
// :77:27: error: use of undefined value here causes illegal behavior
// :77:27: note: when computing vector element at index '0'
// :77:27: error: use of undefined value here causes illegal behavior
// :77:27: error: use of undefined value here causes illegal behavior
// :77:27: error: use of undefined value here causes illegal behavior
// :77:27: note: when computing vector element at index '0'
// :77:27: error: use of undefined value here causes illegal behavior
// :77:27: note: when computing vector element at index '0'
// :77:27: error: use of undefined value here causes illegal behavior
// :77:27: note: when computing vector element at index '0'
// :77:27: error: use of undefined value here causes illegal behavior
// :77:27: note: when computing vector element at index '0'
// :77:27: error: use of undefined value here causes illegal behavior
// :77:27: note: when computing vector element at index '1'
// :77:27: error: use of undefined value here causes illegal behavior
// :77:27: note: when computing vector element at index '1'
// :77:27: error: use of undefined value here causes illegal behavior
// :77:27: note: when computing vector element at index '0'
// :77:27: error: use of undefined value here causes illegal behavior
// :77:27: note: when computing vector element at index '0'
// :77:27: error: use of undefined value here causes illegal behavior
// :77:27: note: when computing vector element at index '0'
// :77:27: error: use of undefined value here causes illegal behavior
// :77:27: note: when computing vector element at index '0'
// :77:27: error: use of undefined value here causes illegal behavior
// :77:27: error: use of undefined value here causes illegal behavior
// :77:27: error: use of undefined value here causes illegal behavior
// :77:27: note: when computing vector element at index '0'
// :77:27: error: use of undefined value here causes illegal behavior
// :77:27: note: when computing vector element at index '0'
// :77:27: error: use of undefined value here causes illegal behavior
// :77:27: note: when computing vector element at index '0'
// :77:27: error: use of undefined value here causes illegal behavior
// :77:27: note: when computing vector element at index '0'
// :77:27: error: use of undefined value here causes illegal behavior
// :77:27: note: when computing vector element at index '1'
// :77:27: error: use of undefined value here causes illegal behavior
// :77:27: note: when computing vector element at index '1'
// :77:27: error: use of undefined value here causes illegal behavior
// :77:27: note: when computing vector element at index '0'
// :77:27: error: use of undefined value here causes illegal behavior
// :77:27: note: when computing vector element at index '0'
// :77:27: error: use of undefined value here causes illegal behavior
// :77:27: note: when computing vector element at index '0'
// :77:27: error: use of undefined value here causes illegal behavior
// :77:27: note: when computing vector element at index '0'
// :77:27: error: use of undefined value here causes illegal behavior
// :77:27: error: use of undefined value here causes illegal behavior
// :77:27: error: use of undefined value here causes illegal behavior
// :77:27: note: when computing vector element at index '0'
// :77:27: error: use of undefined value here causes illegal behavior
// :77:27: note: when computing vector element at index '0'
// :77:27: error: use of undefined value here causes illegal behavior
// :77:27: note: when computing vector element at index '0'
// :77:27: error: use of undefined value here causes illegal behavior
// :77:27: note: when computing vector element at index '0'
// :77:27: error: use of undefined value here causes illegal behavior
// :77:27: note: when computing vector element at index '1'
// :77:27: error: use of undefined value here causes illegal behavior
// :77:27: note: when computing vector element at index '1'
// :77:27: error: use of undefined value here causes illegal behavior
// :77:27: note: when computing vector element at index '0'
// :77:27: error: use of undefined value here causes illegal behavior
// :77:27: note: when computing vector element at index '0'
// :77:27: error: use of undefined value here causes illegal behavior
// :77:27: note: when computing vector element at index '0'
// :77:27: error: use of undefined value here causes illegal behavior
// :77:27: note: when computing vector element at index '0'
// :77:27: error: use of undefined value here causes illegal behavior
// :77:27: error: use of undefined value here causes illegal behavior
// :77:27: error: use of undefined value here causes illegal behavior
// :77:27: note: when computing vector element at index '0'
// :77:27: error: use of undefined value here causes illegal behavior
// :77:27: note: when computing vector element at index '0'
// :77:27: error: use of undefined value here causes illegal behavior
// :77:27: note: when computing vector element at index '0'
// :77:27: error: use of undefined value here causes illegal behavior
// :77:27: note: when computing vector element at index '0'
// :77:27: error: use of undefined value here causes illegal behavior
// :77:27: note: when computing vector element at index '1'
// :77:27: error: use of undefined value here causes illegal behavior
// :77:27: note: when computing vector element at index '1'
// :77:27: error: use of undefined value here causes illegal behavior
// :77:27: note: when computing vector element at index '0'
// :77:27: error: use of undefined value here causes illegal behavior
// :77:27: note: when computing vector element at index '0'
// :77:27: error: use of undefined value here causes illegal behavior
// :77:27: note: when computing vector element at index '0'
// :77:27: error: use of undefined value here causes illegal behavior
// :77:27: note: when computing vector element at index '0'
// :77:27: error: use of undefined value here causes illegal behavior
// :77:27: error: use of undefined value here causes illegal behavior
// :77:27: error: use of undefined value here causes illegal behavior
// :77:27: note: when computing vector element at index '0'
// :77:27: error: use of undefined value here causes illegal behavior
// :77:27: note: when computing vector element at index '0'
// :77:27: error: use of undefined value here causes illegal behavior
// :77:27: note: when computing vector element at index '0'
// :77:27: error: use of undefined value here causes illegal behavior
// :77:27: note: when computing vector element at index '0'
// :77:27: error: use of undefined value here causes illegal behavior
// :77:27: note: when computing vector element at index '1'
// :77:27: error: use of undefined value here causes illegal behavior
// :77:27: note: when computing vector element at index '1'
// :77:27: error: use of undefined value here causes illegal behavior
// :77:27: note: when computing vector element at index '0'
// :77:27: error: use of undefined value here causes illegal behavior
// :77:27: note: when computing vector element at index '0'
// :77:27: error: use of undefined value here causes illegal behavior
// :77:27: note: when computing vector element at index '0'
// :77:27: error: use of undefined value here causes illegal behavior
// :77:27: note: when computing vector element at index '0'
// :77:27: error: use of undefined value here causes illegal behavior
// :77:27: error: use of undefined value here causes illegal behavior
// :77:27: error: use of undefined value here causes illegal behavior
// :77:27: note: when computing vector element at index '0'
// :77:27: error: use of undefined value here causes illegal behavior
// :77:27: note: when computing vector element at index '0'
// :77:27: error: use of undefined value here causes illegal behavior
// :77:27: note: when computing vector element at index '0'
// :77:27: error: use of undefined value here causes illegal behavior
// :77:27: note: when computing vector element at index '0'
// :77:27: error: use of undefined value here causes illegal behavior
// :77:27: note: when computing vector element at index '1'
// :77:27: error: use of undefined value here causes illegal behavior
// :77:27: note: when computing vector element at index '1'
// :77:27: error: use of undefined value here causes illegal behavior
// :77:27: note: when computing vector element at index '0'
// :77:27: error: use of undefined value here causes illegal behavior
// :77:27: note: when computing vector element at index '0'
// :77:27: error: use of undefined value here causes illegal behavior
// :77:27: note: when computing vector element at index '0'
// :77:27: error: use of undefined value here causes illegal behavior
// :77:27: note: when computing vector element at index '0'
// :77:30: error: use of undefined value here causes illegal behavior
// :77:30: note: when computing vector element at index '0'
// :77:30: error: use of undefined value here causes illegal behavior
// :77:30: note: when computing vector element at index '0'
// :77:30: error: use of undefined value here causes illegal behavior
// :77:30: note: when computing vector element at index '0'
// :77:30: error: use of undefined value here causes illegal behavior
// :77:30: note: when computing vector element at index '0'
// :77:30: error: use of undefined value here causes illegal behavior
// :77:30: note: when computing vector element at index '0'
// :77:30: error: use of undefined value here causes illegal behavior
// :77:30: note: when computing vector element at index '0'
// :77:30: error: use of undefined value here causes illegal behavior
// :77:30: note: when computing vector element at index '0'
// :77:30: error: use of undefined value here causes illegal behavior
// :77:30: note: when computing vector element at index '0'
// :77:30: error: use of undefined value here causes illegal behavior
// :77:30: note: when computing vector element at index '0'
// :77:30: error: use of undefined value here causes illegal behavior
// :77:30: note: when computing vector element at index '0'
// :77:30: error: use of undefined value here causes illegal behavior
// :77:30: note: when computing vector element at index '0'
// :77:30: error: use of undefined value here causes illegal behavior
// :77:30: note: when computing vector element at index '0'
// :77:30: error: use of undefined value here causes illegal behavior
// :77:30: note: when computing vector element at index '0'
// :77:30: error: use of undefined value here causes illegal behavior
// :77:30: note: when computing vector element at index '0'
// :77:30: error: use of undefined value here causes illegal behavior
// :77:30: note: when computing vector element at index '0'
// :77:30: error: use of undefined value here causes illegal behavior
// :77:30: note: when computing vector element at index '0'
// :77:30: error: use of undefined value here causes illegal behavior
// :77:30: note: when computing vector element at index '0'
// :77:30: error: use of undefined value here causes illegal behavior
// :77:30: note: when computing vector element at index '0'
// :77:30: error: use of undefined value here causes illegal behavior
// :77:30: note: when computing vector element at index '0'
// :77:30: error: use of undefined value here causes illegal behavior
// :77:30: note: when computing vector element at index '0'
// :77:30: error: use of undefined value here causes illegal behavior
// :77:30: note: when computing vector element at index '0'
// :77:30: error: use of undefined value here causes illegal behavior
// :77:30: note: when computing vector element at index '0'
// :81:17: error: use of undefined value here causes illegal behavior
// :81:17: error: use of undefined value here causes illegal behavior
// :81:17: error: use of undefined value here causes illegal behavior
// :81:17: note: when computing vector element at index '0'
// :81:17: error: use of undefined value here causes illegal behavior
// :81:17: note: when computing vector element at index '0'
// :81:17: error: use of undefined value here causes illegal behavior
// :81:17: note: when computing vector element at index '0'
// :81:17: error: use of undefined value here causes illegal behavior
// :81:17: note: when computing vector element at index '0'
// :81:17: error: use of undefined value here causes illegal behavior
// :81:17: note: when computing vector element at index '1'
// :81:17: error: use of undefined value here causes illegal behavior
// :81:17: note: when computing vector element at index '1'
// :81:17: error: use of undefined value here causes illegal behavior
// :81:17: note: when computing vector element at index '0'
// :81:17: error: use of undefined value here causes illegal behavior
// :81:17: note: when computing vector element at index '0'
// :81:17: error: use of undefined value here causes illegal behavior
// :81:17: note: when computing vector element at index '0'
// :81:17: error: use of undefined value here causes illegal behavior
// :81:17: note: when computing vector element at index '0'
// :81:17: error: use of undefined value here causes illegal behavior
// :81:17: error: use of undefined value here causes illegal behavior
// :81:17: error: use of undefined value here causes illegal behavior
// :81:17: note: when computing vector element at index '0'
// :81:17: error: use of undefined value here causes illegal behavior
// :81:17: note: when computing vector element at index '0'
// :81:17: error: use of undefined value here causes illegal behavior
// :81:17: note: when computing vector element at index '0'
// :81:17: error: use of undefined value here causes illegal behavior
// :81:17: note: when computing vector element at index '0'
// :81:17: error: use of undefined value here causes illegal behavior
// :81:17: note: when computing vector element at index '1'
// :81:17: error: use of undefined value here causes illegal behavior
// :81:17: note: when computing vector element at index '1'
// :81:17: error: use of undefined value here causes illegal behavior
// :81:17: note: when computing vector element at index '0'
// :81:17: error: use of undefined value here causes illegal behavior
// :81:17: note: when computing vector element at index '0'
// :81:17: error: use of undefined value here causes illegal behavior
// :81:17: note: when computing vector element at index '0'
// :81:17: error: use of undefined value here causes illegal behavior
// :81:17: note: when computing vector element at index '0'
// :81:17: error: use of undefined value here causes illegal behavior
// :81:17: error: use of undefined value here causes illegal behavior
// :81:17: error: use of undefined value here causes illegal behavior
// :81:17: note: when computing vector element at index '0'
// :81:17: error: use of undefined value here causes illegal behavior
// :81:17: note: when computing vector element at index '0'
// :81:17: error: use of undefined value here causes illegal behavior
// :81:17: note: when computing vector element at index '0'
// :81:17: error: use of undefined value here causes illegal behavior
// :81:17: note: when computing vector element at index '0'
// :81:17: error: use of undefined value here causes illegal behavior
// :81:17: note: when computing vector element at index '1'
// :81:17: error: use of undefined value here causes illegal behavior
// :81:17: note: when computing vector element at index '1'
// :81:17: error: use of undefined value here causes illegal behavior
// :81:17: note: when computing vector element at index '0'
// :81:17: error: use of undefined value here causes illegal behavior
// :81:17: note: when computing vector element at index '0'
// :81:17: error: use of undefined value here causes illegal behavior
// :81:17: note: when computing vector element at index '0'
// :81:17: error: use of undefined value here causes illegal behavior
// :81:17: note: when computing vector element at index '0'
// :81:17: error: use of undefined value here causes illegal behavior
// :81:17: error: use of undefined value here causes illegal behavior
// :81:17: error: use of undefined value here causes illegal behavior
// :81:17: note: when computing vector element at index '0'
// :81:17: error: use of undefined value here causes illegal behavior
// :81:17: note: when computing vector element at index '0'
// :81:17: error: use of undefined value here causes illegal behavior
// :81:17: note: when computing vector element at index '0'
// :81:17: error: use of undefined value here causes illegal behavior
// :81:17: note: when computing vector element at index '0'
// :81:17: error: use of undefined value here causes illegal behavior
// :81:17: note: when computing vector element at index '1'
// :81:17: error: use of undefined value here causes illegal behavior
// :81:17: note: when computing vector element at index '1'
// :81:17: error: use of undefined value here causes illegal behavior
// :81:17: note: when computing vector element at index '0'
// :81:17: error: use of undefined value here causes illegal behavior
// :81:17: note: when computing vector element at index '0'
// :81:17: error: use of undefined value here causes illegal behavior
// :81:17: note: when computing vector element at index '0'
// :81:17: error: use of undefined value here causes illegal behavior
// :81:17: note: when computing vector element at index '0'
// :81:17: error: use of undefined value here causes illegal behavior
// :81:17: error: use of undefined value here causes illegal behavior
// :81:17: error: use of undefined value here causes illegal behavior
// :81:17: note: when computing vector element at index '0'
// :81:17: error: use of undefined value here causes illegal behavior
// :81:17: note: when computing vector element at index '0'
// :81:17: error: use of undefined value here causes illegal behavior
// :81:17: note: when computing vector element at index '0'
// :81:17: error: use of undefined value here causes illegal behavior
// :81:17: note: when computing vector element at index '0'
// :81:17: error: use of undefined value here causes illegal behavior
// :81:17: note: when computing vector element at index '1'
// :81:17: error: use of undefined value here causes illegal behavior
// :81:17: note: when computing vector element at index '1'
// :81:17: error: use of undefined value here causes illegal behavior
// :81:17: note: when computing vector element at index '0'
// :81:17: error: use of undefined value here causes illegal behavior
// :81:17: note: when computing vector element at index '0'
// :81:17: error: use of undefined value here causes illegal behavior
// :81:17: note: when computing vector element at index '0'
// :81:17: error: use of undefined value here causes illegal behavior
// :81:17: note: when computing vector element at index '0'
// :81:17: error: use of undefined value here causes illegal behavior
// :81:17: error: use of undefined value here causes illegal behavior
// :81:17: error: use of undefined value here causes illegal behavior
// :81:17: note: when computing vector element at index '0'
// :81:17: error: use of undefined value here causes illegal behavior
// :81:17: note: when computing vector element at index '0'
// :81:17: error: use of undefined value here causes illegal behavior
// :81:17: note: when computing vector element at index '0'
// :81:17: error: use of undefined value here causes illegal behavior
// :81:17: note: when computing vector element at index '0'
// :81:17: error: use of undefined value here causes illegal behavior
// :81:17: note: when computing vector element at index '1'
// :81:17: error: use of undefined value here causes illegal behavior
// :81:17: note: when computing vector element at index '1'
// :81:17: error: use of undefined value here causes illegal behavior
// :81:17: note: when computing vector element at index '0'
// :81:17: error: use of undefined value here causes illegal behavior
// :81:17: note: when computing vector element at index '0'
// :81:17: error: use of undefined value here causes illegal behavior
// :81:17: note: when computing vector element at index '0'
// :81:17: error: use of undefined value here causes illegal behavior
// :81:17: note: when computing vector element at index '0'
// :81:17: error: use of undefined value here causes illegal behavior
// :81:17: error: use of undefined value here causes illegal behavior
// :81:17: error: use of undefined value here causes illegal behavior
// :81:17: note: when computing vector element at index '0'
// :81:17: error: use of undefined value here causes illegal behavior
// :81:17: note: when computing vector element at index '0'
// :81:17: error: use of undefined value here causes illegal behavior
// :81:17: note: when computing vector element at index '0'
// :81:17: error: use of undefined value here causes illegal behavior
// :81:17: note: when computing vector element at index '0'
// :81:17: error: use of undefined value here causes illegal behavior
// :81:17: note: when computing vector element at index '1'
// :81:17: error: use of undefined value here causes illegal behavior
// :81:17: note: when computing vector element at index '1'
// :81:17: error: use of undefined value here causes illegal behavior
// :81:17: note: when computing vector element at index '0'
// :81:17: error: use of undefined value here causes illegal behavior
// :81:17: note: when computing vector element at index '0'
// :81:17: error: use of undefined value here causes illegal behavior
// :81:17: note: when computing vector element at index '0'
// :81:17: error: use of undefined value here causes illegal behavior
// :81:17: note: when computing vector element at index '0'
// :81:17: error: use of undefined value here causes illegal behavior
// :81:17: error: use of undefined value here causes illegal behavior
// :81:17: error: use of undefined value here causes illegal behavior
// :81:17: note: when computing vector element at index '0'
// :81:17: error: use of undefined value here causes illegal behavior
// :81:17: note: when computing vector element at index '0'
// :81:17: error: use of undefined value here causes illegal behavior
// :81:17: note: when computing vector element at index '0'
// :81:17: error: use of undefined value here causes illegal behavior
// :81:17: note: when computing vector element at index '0'
// :81:17: error: use of undefined value here causes illegal behavior
// :81:17: note: when computing vector element at index '1'
// :81:17: error: use of undefined value here causes illegal behavior
// :81:17: note: when computing vector element at index '1'
// :81:17: error: use of undefined value here causes illegal behavior
// :81:17: note: when computing vector element at index '0'
// :81:17: error: use of undefined value here causes illegal behavior
// :81:17: note: when computing vector element at index '0'
// :81:17: error: use of undefined value here causes illegal behavior
// :81:17: note: when computing vector element at index '0'
// :81:17: error: use of undefined value here causes illegal behavior
// :81:17: note: when computing vector element at index '0'
// :81:17: error: use of undefined value here causes illegal behavior
// :81:17: error: use of undefined value here causes illegal behavior
// :81:17: error: use of undefined value here causes illegal behavior
// :81:17: note: when computing vector element at index '0'
// :81:17: error: use of undefined value here causes illegal behavior
// :81:17: note: when computing vector element at index '0'
// :81:17: error: use of undefined value here causes illegal behavior
// :81:17: note: when computing vector element at index '0'
// :81:17: error: use of undefined value here causes illegal behavior
// :81:17: note: when computing vector element at index '0'
// :81:17: error: use of undefined value here causes illegal behavior
// :81:17: note: when computing vector element at index '1'
// :81:17: error: use of undefined value here causes illegal behavior
// :81:17: note: when computing vector element at index '1'
// :81:17: error: use of undefined value here causes illegal behavior
// :81:17: note: when computing vector element at index '0'
// :81:17: error: use of undefined value here causes illegal behavior
// :81:17: note: when computing vector element at index '0'
// :81:17: error: use of undefined value here causes illegal behavior
// :81:17: note: when computing vector element at index '0'
// :81:17: error: use of undefined value here causes illegal behavior
// :81:17: note: when computing vector element at index '0'
// :81:17: error: use of undefined value here causes illegal behavior
// :81:17: error: use of undefined value here causes illegal behavior
// :81:17: error: use of undefined value here causes illegal behavior
// :81:17: note: when computing vector element at index '0'
// :81:17: error: use of undefined value here causes illegal behavior
// :81:17: note: when computing vector element at index '0'
// :81:17: error: use of undefined value here causes illegal behavior
// :81:17: note: when computing vector element at index '0'
// :81:17: error: use of undefined value here causes illegal behavior
// :81:17: note: when computing vector element at index '0'
// :81:17: error: use of undefined value here causes illegal behavior
// :81:17: note: when computing vector element at index '1'
// :81:17: error: use of undefined value here causes illegal behavior
// :81:17: note: when computing vector element at index '1'
// :81:17: error: use of undefined value here causes illegal behavior
// :81:17: note: when computing vector element at index '0'
// :81:17: error: use of undefined value here causes illegal behavior
// :81:17: note: when computing vector element at index '0'
// :81:17: error: use of undefined value here causes illegal behavior
// :81:17: note: when computing vector element at index '0'
// :81:17: error: use of undefined value here causes illegal behavior
// :81:17: note: when computing vector element at index '0'
// :81:17: error: use of undefined value here causes illegal behavior
// :81:17: error: use of undefined value here causes illegal behavior
// :81:17: error: use of undefined value here causes illegal behavior
// :81:17: note: when computing vector element at index '0'
// :81:17: error: use of undefined value here causes illegal behavior
// :81:17: note: when computing vector element at index '0'
// :81:17: error: use of undefined value here causes illegal behavior
// :81:17: note: when computing vector element at index '0'
// :81:17: error: use of undefined value here causes illegal behavior
// :81:17: note: when computing vector element at index '0'
// :81:17: error: use of undefined value here causes illegal behavior
// :81:17: note: when computing vector element at index '1'
// :81:17: error: use of undefined value here causes illegal behavior
// :81:17: note: when computing vector element at index '1'
// :81:17: error: use of undefined value here causes illegal behavior
// :81:17: note: when computing vector element at index '0'
// :81:17: error: use of undefined value here causes illegal behavior
// :81:17: note: when computing vector element at index '0'
// :81:17: error: use of undefined value here causes illegal behavior
// :81:17: note: when computing vector element at index '0'
// :81:17: error: use of undefined value here causes illegal behavior
// :81:17: note: when computing vector element at index '0'
// :81:21: error: use of undefined value here causes illegal behavior
// :81:21: note: when computing vector element at index '0'
// :81:21: error: use of undefined value here causes illegal behavior
// :81:21: note: when computing vector element at index '0'
// :81:21: error: use of undefined value here causes illegal behavior
// :81:21: note: when computing vector element at index '0'
// :81:21: error: use of undefined value here causes illegal behavior
// :81:21: note: when computing vector element at index '0'
// :81:21: error: use of undefined value here causes illegal behavior
// :81:21: note: when computing vector element at index '0'
// :81:21: error: use of undefined value here causes illegal behavior
// :81:21: note: when computing vector element at index '0'
// :81:21: error: use of undefined value here causes illegal behavior
// :81:21: note: when computing vector element at index '0'
// :81:21: error: use of undefined value here causes illegal behavior
// :81:21: note: when computing vector element at index '0'
// :81:21: error: use of undefined value here causes illegal behavior
// :81:21: note: when computing vector element at index '0'
// :81:21: error: use of undefined value here causes illegal behavior
// :81:21: note: when computing vector element at index '0'
// :81:21: error: use of undefined value here causes illegal behavior
// :81:21: note: when computing vector element at index '0'
// :81:21: error: use of undefined value here causes illegal behavior
// :81:21: note: when computing vector element at index '0'
// :81:21: error: use of undefined value here causes illegal behavior
// :81:21: note: when computing vector element at index '0'
// :81:21: error: use of undefined value here causes illegal behavior
// :81:21: note: when computing vector element at index '0'
// :81:21: error: use of undefined value here causes illegal behavior
// :81:21: note: when computing vector element at index '0'
// :81:21: error: use of undefined value here causes illegal behavior
// :81:21: note: when computing vector element at index '0'
// :81:21: error: use of undefined value here causes illegal behavior
// :81:21: note: when computing vector element at index '0'
// :81:21: error: use of undefined value here causes illegal behavior
// :81:21: note: when computing vector element at index '0'
// :81:21: error: use of undefined value here causes illegal behavior
// :81:21: note: when computing vector element at index '0'
// :81:21: error: use of undefined value here causes illegal behavior
// :81:21: note: when computing vector element at index '0'
// :81:21: error: use of undefined value here causes illegal behavior
// :81:21: note: when computing vector element at index '0'
// :81:21: error: use of undefined value here causes illegal behavior
// :81:21: note: when computing vector element at index '0'
// :85:22: error: use of undefined value here causes illegal behavior
// :85:22: error: use of undefined value here causes illegal behavior
// :85:22: error: use of undefined value here causes illegal behavior
// :85:22: note: when computing vector element at index '0'
// :85:22: error: use of undefined value here causes illegal behavior
// :85:22: note: when computing vector element at index '0'
// :85:22: error: use of undefined value here causes illegal behavior
// :85:22: note: when computing vector element at index '0'
// :85:22: error: use of undefined value here causes illegal behavior
// :85:22: note: when computing vector element at index '0'
// :85:22: error: use of undefined value here causes illegal behavior
// :85:22: note: when computing vector element at index '1'
// :85:22: error: use of undefined value here causes illegal behavior
// :85:22: note: when computing vector element at index '1'
// :85:22: error: use of undefined value here causes illegal behavior
// :85:22: note: when computing vector element at index '0'
// :85:22: error: use of undefined value here causes illegal behavior
// :85:22: note: when computing vector element at index '0'
// :85:22: error: use of undefined value here causes illegal behavior
// :85:22: note: when computing vector element at index '0'
// :85:22: error: use of undefined value here causes illegal behavior
// :85:22: note: when computing vector element at index '0'
// :85:22: error: use of undefined value here causes illegal behavior
// :85:22: error: use of undefined value here causes illegal behavior
// :85:22: error: use of undefined value here causes illegal behavior
// :85:22: note: when computing vector element at index '0'
// :85:22: error: use of undefined value here causes illegal behavior
// :85:22: note: when computing vector element at index '0'
// :85:22: error: use of undefined value here causes illegal behavior
// :85:22: note: when computing vector element at index '0'
// :85:22: error: use of undefined value here causes illegal behavior
// :85:22: note: when computing vector element at index '0'
// :85:22: error: use of undefined value here causes illegal behavior
// :85:22: note: when computing vector element at index '1'
// :85:22: error: use of undefined value here causes illegal behavior
// :85:22: note: when computing vector element at index '1'
// :85:22: error: use of undefined value here causes illegal behavior
// :85:22: note: when computing vector element at index '0'
// :85:22: error: use of undefined value here causes illegal behavior
// :85:22: note: when computing vector element at index '0'
// :85:22: error: use of undefined value here causes illegal behavior
// :85:22: note: when computing vector element at index '0'
// :85:22: error: use of undefined value here causes illegal behavior
// :85:22: note: when computing vector element at index '0'
// :85:22: error: use of undefined value here causes illegal behavior
// :85:22: error: use of undefined value here causes illegal behavior
// :85:22: error: use of undefined value here causes illegal behavior
// :85:22: note: when computing vector element at index '0'
// :85:22: error: use of undefined value here causes illegal behavior
// :85:22: note: when computing vector element at index '0'
// :85:22: error: use of undefined value here causes illegal behavior
// :85:22: note: when computing vector element at index '0'
// :85:22: error: use of undefined value here causes illegal behavior
// :85:22: note: when computing vector element at index '0'
// :85:22: error: use of undefined value here causes illegal behavior
// :85:22: note: when computing vector element at index '1'
// :85:22: error: use of undefined value here causes illegal behavior
// :85:22: note: when computing vector element at index '1'
// :85:22: error: use of undefined value here causes illegal behavior
// :85:22: note: when computing vector element at index '0'
// :85:22: error: use of undefined value here causes illegal behavior
// :85:22: note: when computing vector element at index '0'
// :85:22: error: use of undefined value here causes illegal behavior
// :85:22: note: when computing vector element at index '0'
// :85:22: error: use of undefined value here causes illegal behavior
// :85:22: note: when computing vector element at index '0'
// :85:22: error: use of undefined value here causes illegal behavior
// :85:22: error: use of undefined value here causes illegal behavior
// :85:22: error: use of undefined value here causes illegal behavior
// :85:22: note: when computing vector element at index '0'
// :85:22: error: use of undefined value here causes illegal behavior
// :85:22: note: when computing vector element at index '0'
// :85:22: error: use of undefined value here causes illegal behavior
// :85:22: note: when computing vector element at index '0'
// :85:22: error: use of undefined value here causes illegal behavior
// :85:22: note: when computing vector element at index '0'
// :85:22: error: use of undefined value here causes illegal behavior
// :85:22: note: when computing vector element at index '1'
// :85:22: error: use of undefined value here causes illegal behavior
// :85:22: note: when computing vector element at index '1'
// :85:22: error: use of undefined value here causes illegal behavior
// :85:22: note: when computing vector element at index '0'
// :85:22: error: use of undefined value here causes illegal behavior
// :85:22: note: when computing vector element at index '0'
// :85:22: error: use of undefined value here causes illegal behavior
// :85:22: note: when computing vector element at index '0'
// :85:22: error: use of undefined value here causes illegal behavior
// :85:22: note: when computing vector element at index '0'
// :85:22: error: use of undefined value here causes illegal behavior
// :85:22: error: use of undefined value here causes illegal behavior
// :85:22: error: use of undefined value here causes illegal behavior
// :85:22: note: when computing vector element at index '0'
// :85:22: error: use of undefined value here causes illegal behavior
// :85:22: note: when computing vector element at index '0'
// :85:22: error: use of undefined value here causes illegal behavior
// :85:22: note: when computing vector element at index '0'
// :85:22: error: use of undefined value here causes illegal behavior
// :85:22: note: when computing vector element at index '0'
// :85:22: error: use of undefined value here causes illegal behavior
// :85:22: note: when computing vector element at index '1'
// :85:22: error: use of undefined value here causes illegal behavior
// :85:22: note: when computing vector element at index '1'
// :85:22: error: use of undefined value here causes illegal behavior
// :85:22: note: when computing vector element at index '0'
// :85:22: error: use of undefined value here causes illegal behavior
// :85:22: note: when computing vector element at index '0'
// :85:22: error: use of undefined value here causes illegal behavior
// :85:22: note: when computing vector element at index '0'
// :85:22: error: use of undefined value here causes illegal behavior
// :85:22: note: when computing vector element at index '0'
// :85:22: error: use of undefined value here causes illegal behavior
// :85:22: error: use of undefined value here causes illegal behavior
// :85:22: error: use of undefined value here causes illegal behavior
// :85:22: note: when computing vector element at index '0'
// :85:22: error: use of undefined value here causes illegal behavior
// :85:22: note: when computing vector element at index '0'
// :85:22: error: use of undefined value here causes illegal behavior
// :85:22: note: when computing vector element at index '0'
// :85:22: error: use of undefined value here causes illegal behavior
// :85:22: note: when computing vector element at index '0'
// :85:22: error: use of undefined value here causes illegal behavior
// :85:22: note: when computing vector element at index '1'
// :85:22: error: use of undefined value here causes illegal behavior
// :85:22: note: when computing vector element at index '1'
// :85:22: error: use of undefined value here causes illegal behavior
// :85:22: note: when computing vector element at index '0'
// :85:22: error: use of undefined value here causes illegal behavior
// :85:22: note: when computing vector element at index '0'
// :85:22: error: use of undefined value here causes illegal behavior
// :85:22: note: when computing vector element at index '0'
// :85:22: error: use of undefined value here causes illegal behavior
// :85:22: note: when computing vector element at index '0'
// :85:22: error: use of undefined value here causes illegal behavior
// :85:22: error: use of undefined value here causes illegal behavior
// :85:22: error: use of undefined value here causes illegal behavior
// :85:22: note: when computing vector element at index '0'
// :85:22: error: use of undefined value here causes illegal behavior
// :85:22: note: when computing vector element at index '0'
// :85:22: error: use of undefined value here causes illegal behavior
// :85:22: note: when computing vector element at index '0'
// :85:22: error: use of undefined value here causes illegal behavior
// :85:22: note: when computing vector element at index '0'
// :85:22: error: use of undefined value here causes illegal behavior
// :85:22: note: when computing vector element at index '1'
// :85:22: error: use of undefined value here causes illegal behavior
// :85:22: note: when computing vector element at index '1'
// :85:22: error: use of undefined value here causes illegal behavior
// :85:22: note: when computing vector element at index '0'
// :85:22: error: use of undefined value here causes illegal behavior
// :85:22: note: when computing vector element at index '0'
// :85:22: error: use of undefined value here causes illegal behavior
// :85:22: note: when computing vector element at index '0'
// :85:22: error: use of undefined value here causes illegal behavior
// :85:22: note: when computing vector element at index '0'
// :85:22: error: use of undefined value here causes illegal behavior
// :85:22: error: use of undefined value here causes illegal behavior
// :85:22: error: use of undefined value here causes illegal behavior
// :85:22: note: when computing vector element at index '0'
// :85:22: error: use of undefined value here causes illegal behavior
// :85:22: note: when computing vector element at index '0'
// :85:22: error: use of undefined value here causes illegal behavior
// :85:22: note: when computing vector element at index '0'
// :85:22: error: use of undefined value here causes illegal behavior
// :85:22: note: when computing vector element at index '0'
// :85:22: error: use of undefined value here causes illegal behavior
// :85:22: note: when computing vector element at index '1'
// :85:22: error: use of undefined value here causes illegal behavior
// :85:22: note: when computing vector element at index '1'
// :85:22: error: use of undefined value here causes illegal behavior
// :85:22: note: when computing vector element at index '0'
// :85:22: error: use of undefined value here causes illegal behavior
// :85:22: note: when computing vector element at index '0'
// :85:22: error: use of undefined value here causes illegal behavior
// :85:22: note: when computing vector element at index '0'
// :85:22: error: use of undefined value here causes illegal behavior
// :85:22: note: when computing vector element at index '0'
// :85:22: error: use of undefined value here causes illegal behavior
// :85:22: error: use of undefined value here causes illegal behavior
// :85:22: error: use of undefined value here causes illegal behavior
// :85:22: note: when computing vector element at index '0'
// :85:22: error: use of undefined value here causes illegal behavior
// :85:22: note: when computing vector element at index '0'
// :85:22: error: use of undefined value here causes illegal behavior
// :85:22: note: when computing vector element at index '0'
// :85:22: error: use of undefined value here causes illegal behavior
// :85:22: note: when computing vector element at index '0'
// :85:22: error: use of undefined value here causes illegal behavior
// :85:22: note: when computing vector element at index '1'
// :85:22: error: use of undefined value here causes illegal behavior
// :85:22: note: when computing vector element at index '1'
// :85:22: error: use of undefined value here causes illegal behavior
// :85:22: note: when computing vector element at index '0'
// :85:22: error: use of undefined value here causes illegal behavior
// :85:22: note: when computing vector element at index '0'
// :85:22: error: use of undefined value here causes illegal behavior
// :85:22: note: when computing vector element at index '0'
// :85:22: error: use of undefined value here causes illegal behavior
// :85:22: note: when computing vector element at index '0'
// :85:22: error: use of undefined value here causes illegal behavior
// :85:22: error: use of undefined value here causes illegal behavior
// :85:22: error: use of undefined value here causes illegal behavior
// :85:22: note: when computing vector element at index '0'
// :85:22: error: use of undefined value here causes illegal behavior
// :85:22: note: when computing vector element at index '0'
// :85:22: error: use of undefined value here causes illegal behavior
// :85:22: note: when computing vector element at index '0'
// :85:22: error: use of undefined value here causes illegal behavior
// :85:22: note: when computing vector element at index '0'
// :85:22: error: use of undefined value here causes illegal behavior
// :85:22: note: when computing vector element at index '1'
// :85:22: error: use of undefined value here causes illegal behavior
// :85:22: note: when computing vector element at index '1'
// :85:22: error: use of undefined value here causes illegal behavior
// :85:22: note: when computing vector element at index '0'
// :85:22: error: use of undefined value here causes illegal behavior
// :85:22: note: when computing vector element at index '0'
// :85:22: error: use of undefined value here causes illegal behavior
// :85:22: note: when computing vector element at index '0'
// :85:22: error: use of undefined value here causes illegal behavior
// :85:22: note: when computing vector element at index '0'
// :85:22: error: use of undefined value here causes illegal behavior
// :85:22: error: use of undefined value here causes illegal behavior
// :85:22: error: use of undefined value here causes illegal behavior
// :85:22: note: when computing vector element at index '0'
// :85:22: error: use of undefined value here causes illegal behavior
// :85:22: note: when computing vector element at index '0'
// :85:22: error: use of undefined value here causes illegal behavior
// :85:22: note: when computing vector element at index '0'
// :85:22: error: use of undefined value here causes illegal behavior
// :85:22: note: when computing vector element at index '0'
// :85:22: error: use of undefined value here causes illegal behavior
// :85:22: note: when computing vector element at index '1'
// :85:22: error: use of undefined value here causes illegal behavior
// :85:22: note: when computing vector element at index '1'
// :85:22: error: use of undefined value here causes illegal behavior
// :85:22: note: when computing vector element at index '0'
// :85:22: error: use of undefined value here causes illegal behavior
// :85:22: note: when computing vector element at index '0'
// :85:22: error: use of undefined value here causes illegal behavior
// :85:22: note: when computing vector element at index '0'
// :85:22: error: use of undefined value here causes illegal behavior
// :85:22: note: when computing vector element at index '0'
// :85:25: error: use of undefined value here causes illegal behavior
// :85:25: note: when computing vector element at index '0'
// :85:25: error: use of undefined value here causes illegal behavior
// :85:25: note: when computing vector element at index '0'
// :85:25: error: use of undefined value here causes illegal behavior
// :85:25: note: when computing vector element at index '0'
// :85:25: error: use of undefined value here causes illegal behavior
// :85:25: note: when computing vector element at index '0'
// :85:25: error: use of undefined value here causes illegal behavior
// :85:25: note: when computing vector element at index '0'
// :85:25: error: use of undefined value here causes illegal behavior
// :85:25: note: when computing vector element at index '0'
// :85:25: error: use of undefined value here causes illegal behavior
// :85:25: note: when computing vector element at index '0'
// :85:25: error: use of undefined value here causes illegal behavior
// :85:25: note: when computing vector element at index '0'
// :85:25: error: use of undefined value here causes illegal behavior
// :85:25: note: when computing vector element at index '0'
// :85:25: error: use of undefined value here causes illegal behavior
// :85:25: note: when computing vector element at index '0'
// :85:25: error: use of undefined value here causes illegal behavior
// :85:25: note: when computing vector element at index '0'
// :85:25: error: use of undefined value here causes illegal behavior
// :85:25: note: when computing vector element at index '0'
// :85:25: error: use of undefined value here causes illegal behavior
// :85:25: note: when computing vector element at index '0'
// :85:25: error: use of undefined value here causes illegal behavior
// :85:25: note: when computing vector element at index '0'
// :85:25: error: use of undefined value here causes illegal behavior
// :85:25: note: when computing vector element at index '0'
// :85:25: error: use of undefined value here causes illegal behavior
// :85:25: note: when computing vector element at index '0'
// :85:25: error: use of undefined value here causes illegal behavior
// :85:25: note: when computing vector element at index '0'
// :85:25: error: use of undefined value here causes illegal behavior
// :85:25: note: when computing vector element at index '0'
// :85:25: error: use of undefined value here causes illegal behavior
// :85:25: note: when computing vector element at index '0'
// :85:25: error: use of undefined value here causes illegal behavior
// :85:25: note: when computing vector element at index '0'
// :85:25: error: use of undefined value here causes illegal behavior
// :85:25: note: when computing vector element at index '0'
// :85:25: error: use of undefined value here causes illegal behavior
// :85:25: note: when computing vector element at index '0'
// :89:22: error: use of undefined value here causes illegal behavior
// :89:22: error: use of undefined value here causes illegal behavior
// :89:22: error: use of undefined value here causes illegal behavior
// :89:22: note: when computing vector element at index '0'
// :89:22: error: use of undefined value here causes illegal behavior
// :89:22: note: when computing vector element at index '0'
// :89:22: error: use of undefined value here causes illegal behavior
// :89:22: note: when computing vector element at index '0'
// :89:22: error: use of undefined value here causes illegal behavior
// :89:22: note: when computing vector element at index '0'
// :89:22: error: use of undefined value here causes illegal behavior
// :89:22: note: when computing vector element at index '1'
// :89:22: error: use of undefined value here causes illegal behavior
// :89:22: note: when computing vector element at index '1'
// :89:22: error: use of undefined value here causes illegal behavior
// :89:22: note: when computing vector element at index '0'
// :89:22: error: use of undefined value here causes illegal behavior
// :89:22: note: when computing vector element at index '0'
// :89:22: error: use of undefined value here causes illegal behavior
// :89:22: note: when computing vector element at index '0'
// :89:22: error: use of undefined value here causes illegal behavior
// :89:22: note: when computing vector element at index '0'
// :89:22: error: use of undefined value here causes illegal behavior
// :89:22: error: use of undefined value here causes illegal behavior
// :89:22: error: use of undefined value here causes illegal behavior
// :89:22: note: when computing vector element at index '0'
// :89:22: error: use of undefined value here causes illegal behavior
// :89:22: note: when computing vector element at index '0'
// :89:22: error: use of undefined value here causes illegal behavior
// :89:22: note: when computing vector element at index '0'
// :89:22: error: use of undefined value here causes illegal behavior
// :89:22: note: when computing vector element at index '0'
// :89:22: error: use of undefined value here causes illegal behavior
// :89:22: note: when computing vector element at index '1'
// :89:22: error: use of undefined value here causes illegal behavior
// :89:22: note: when computing vector element at index '1'
// :89:22: error: use of undefined value here causes illegal behavior
// :89:22: note: when computing vector element at index '0'
// :89:22: error: use of undefined value here causes illegal behavior
// :89:22: note: when computing vector element at index '0'
// :89:22: error: use of undefined value here causes illegal behavior
// :89:22: note: when computing vector element at index '0'
// :89:22: error: use of undefined value here causes illegal behavior
// :89:22: note: when computing vector element at index '0'
// :89:22: error: use of undefined value here causes illegal behavior
// :89:22: error: use of undefined value here causes illegal behavior
// :89:22: error: use of undefined value here causes illegal behavior
// :89:22: note: when computing vector element at index '0'
// :89:22: error: use of undefined value here causes illegal behavior
// :89:22: note: when computing vector element at index '0'
// :89:22: error: use of undefined value here causes illegal behavior
// :89:22: note: when computing vector element at index '0'
// :89:22: error: use of undefined value here causes illegal behavior
// :89:22: note: when computing vector element at index '0'
// :89:22: error: use of undefined value here causes illegal behavior
// :89:22: note: when computing vector element at index '1'
// :89:22: error: use of undefined value here causes illegal behavior
// :89:22: note: when computing vector element at index '1'
// :89:22: error: use of undefined value here causes illegal behavior
// :89:22: note: when computing vector element at index '0'
// :89:22: error: use of undefined value here causes illegal behavior
// :89:22: note: when computing vector element at index '0'
// :89:22: error: use of undefined value here causes illegal behavior
// :89:22: note: when computing vector element at index '0'
// :89:22: error: use of undefined value here causes illegal behavior
// :89:22: note: when computing vector element at index '0'
// :89:22: error: use of undefined value here causes illegal behavior
// :89:22: error: use of undefined value here causes illegal behavior
// :89:22: error: use of undefined value here causes illegal behavior
// :89:22: note: when computing vector element at index '0'
// :89:22: error: use of undefined value here causes illegal behavior
// :89:22: note: when computing vector element at index '0'
// :89:22: error: use of undefined value here causes illegal behavior
// :89:22: note: when computing vector element at index '0'
// :89:22: error: use of undefined value here causes illegal behavior
// :89:22: note: when computing vector element at index '0'
// :89:22: error: use of undefined value here causes illegal behavior
// :89:22: note: when computing vector element at index '1'
// :89:22: error: use of undefined value here causes illegal behavior
// :89:22: note: when computing vector element at index '1'
// :89:22: error: use of undefined value here causes illegal behavior
// :89:22: note: when computing vector element at index '0'
// :89:22: error: use of undefined value here causes illegal behavior
// :89:22: note: when computing vector element at index '0'
// :89:22: error: use of undefined value here causes illegal behavior
// :89:22: note: when computing vector element at index '0'
// :89:22: error: use of undefined value here causes illegal behavior
// :89:22: note: when computing vector element at index '0'
// :89:22: error: use of undefined value here causes illegal behavior
// :89:22: error: use of undefined value here causes illegal behavior
// :89:22: error: use of undefined value here causes illegal behavior
// :89:22: note: when computing vector element at index '0'
// :89:22: error: use of undefined value here causes illegal behavior
// :89:22: note: when computing vector element at index '0'
// :89:22: error: use of undefined value here causes illegal behavior
// :89:22: note: when computing vector element at index '0'
// :89:22: error: use of undefined value here causes illegal behavior
// :89:22: note: when computing vector element at index '0'
// :89:22: error: use of undefined value here causes illegal behavior
// :89:22: note: when computing vector element at index '1'
// :89:22: error: use of undefined value here causes illegal behavior
// :89:22: note: when computing vector element at index '1'
// :89:22: error: use of undefined value here causes illegal behavior
// :89:22: note: when computing vector element at index '0'
// :89:22: error: use of undefined value here causes illegal behavior
// :89:22: note: when computing vector element at index '0'
// :89:22: error: use of undefined value here causes illegal behavior
// :89:22: note: when computing vector element at index '0'
// :89:22: error: use of undefined value here causes illegal behavior
// :89:22: note: when computing vector element at index '0'
// :89:22: error: use of undefined value here causes illegal behavior
// :89:22: error: use of undefined value here causes illegal behavior
// :89:22: error: use of undefined value here causes illegal behavior
// :89:22: note: when computing vector element at index '0'
// :89:22: error: use of undefined value here causes illegal behavior
// :89:22: note: when computing vector element at index '0'
// :89:22: error: use of undefined value here causes illegal behavior
// :89:22: note: when computing vector element at index '0'
// :89:22: error: use of undefined value here causes illegal behavior
// :89:22: note: when computing vector element at index '0'
// :89:22: error: use of undefined value here causes illegal behavior
// :89:22: note: when computing vector element at index '1'
// :89:22: error: use of undefined value here causes illegal behavior
// :89:22: note: when computing vector element at index '1'
// :89:22: error: use of undefined value here causes illegal behavior
// :89:22: note: when computing vector element at index '0'
// :89:22: error: use of undefined value here causes illegal behavior
// :89:22: note: when computing vector element at index '0'
// :89:22: error: use of undefined value here causes illegal behavior
// :89:22: note: when computing vector element at index '0'
// :89:22: error: use of undefined value here causes illegal behavior
// :89:22: note: when computing vector element at index '0'
// :89:22: error: use of undefined value here causes illegal behavior
// :89:22: error: use of undefined value here causes illegal behavior
// :89:22: error: use of undefined value here causes illegal behavior
// :89:22: note: when computing vector element at index '0'
// :89:22: error: use of undefined value here causes illegal behavior
// :89:22: note: when computing vector element at index '0'
// :89:22: error: use of undefined value here causes illegal behavior
// :89:22: note: when computing vector element at index '0'
// :89:22: error: use of undefined value here causes illegal behavior
// :89:22: note: when computing vector element at index '0'
// :89:22: error: use of undefined value here causes illegal behavior
// :89:22: note: when computing vector element at index '1'
// :89:22: error: use of undefined value here causes illegal behavior
// :89:22: note: when computing vector element at index '1'
// :89:22: error: use of undefined value here causes illegal behavior
// :89:22: note: when computing vector element at index '0'
// :89:22: error: use of undefined value here causes illegal behavior
// :89:22: note: when computing vector element at index '0'
// :89:22: error: use of undefined value here causes illegal behavior
// :89:22: note: when computing vector element at index '0'
// :89:22: error: use of undefined value here causes illegal behavior
// :89:22: note: when computing vector element at index '0'
// :89:22: error: use of undefined value here causes illegal behavior
// :89:22: error: use of undefined value here causes illegal behavior
// :89:22: error: use of undefined value here causes illegal behavior
// :89:22: note: when computing vector element at index '0'
// :89:22: error: use of undefined value here causes illegal behavior
// :89:22: note: when computing vector element at index '0'
// :89:22: error: use of undefined value here causes illegal behavior
// :89:22: note: when computing vector element at index '0'
// :89:22: error: use of undefined value here causes illegal behavior
// :89:22: note: when computing vector element at index '0'
// :89:22: error: use of undefined value here causes illegal behavior
// :89:22: note: when computing vector element at index '1'
// :89:22: error: use of undefined value here causes illegal behavior
// :89:22: note: when computing vector element at index '1'
// :89:22: error: use of undefined value here causes illegal behavior
// :89:22: note: when computing vector element at index '0'
// :89:22: error: use of undefined value here causes illegal behavior
// :89:22: note: when computing vector element at index '0'
// :89:22: error: use of undefined value here causes illegal behavior
// :89:22: note: when computing vector element at index '0'
// :89:22: error: use of undefined value here causes illegal behavior
// :89:22: note: when computing vector element at index '0'
// :89:22: error: use of undefined value here causes illegal behavior
// :89:22: error: use of undefined value here causes illegal behavior
// :89:22: error: use of undefined value here causes illegal behavior
// :89:22: note: when computing vector element at index '0'
// :89:22: error: use of undefined value here causes illegal behavior
// :89:22: note: when computing vector element at index '0'
// :89:22: error: use of undefined value here causes illegal behavior
// :89:22: note: when computing vector element at index '0'
// :89:22: error: use of undefined value here causes illegal behavior
// :89:22: note: when computing vector element at index '0'
// :89:22: error: use of undefined value here causes illegal behavior
// :89:22: note: when computing vector element at index '1'
// :89:22: error: use of undefined value here causes illegal behavior
// :89:22: note: when computing vector element at index '1'
// :89:22: error: use of undefined value here causes illegal behavior
// :89:22: note: when computing vector element at index '0'
// :89:22: error: use of undefined value here causes illegal behavior
// :89:22: note: when computing vector element at index '0'
// :89:22: error: use of undefined value here causes illegal behavior
// :89:22: note: when computing vector element at index '0'
// :89:22: error: use of undefined value here causes illegal behavior
// :89:22: note: when computing vector element at index '0'
// :89:22: error: use of undefined value here causes illegal behavior
// :89:22: error: use of undefined value here causes illegal behavior
// :89:22: error: use of undefined value here causes illegal behavior
// :89:22: note: when computing vector element at index '0'
// :89:22: error: use of undefined value here causes illegal behavior
// :89:22: note: when computing vector element at index '0'
// :89:22: error: use of undefined value here causes illegal behavior
// :89:22: note: when computing vector element at index '0'
// :89:22: error: use of undefined value here causes illegal behavior
// :89:22: note: when computing vector element at index '0'
// :89:22: error: use of undefined value here causes illegal behavior
// :89:22: note: when computing vector element at index '1'
// :89:22: error: use of undefined value here causes illegal behavior
// :89:22: note: when computing vector element at index '1'
// :89:22: error: use of undefined value here causes illegal behavior
// :89:22: note: when computing vector element at index '0'
// :89:22: error: use of undefined value here causes illegal behavior
// :89:22: note: when computing vector element at index '0'
// :89:22: error: use of undefined value here causes illegal behavior
// :89:22: note: when computing vector element at index '0'
// :89:22: error: use of undefined value here causes illegal behavior
// :89:22: note: when computing vector element at index '0'
// :89:22: error: use of undefined value here causes illegal behavior
// :89:22: error: use of undefined value here causes illegal behavior
// :89:22: error: use of undefined value here causes illegal behavior
// :89:22: note: when computing vector element at index '0'
// :89:22: error: use of undefined value here causes illegal behavior
// :89:22: note: when computing vector element at index '0'
// :89:22: error: use of undefined value here causes illegal behavior
// :89:22: note: when computing vector element at index '0'
// :89:22: error: use of undefined value here causes illegal behavior
// :89:22: note: when computing vector element at index '0'
// :89:22: error: use of undefined value here causes illegal behavior
// :89:22: note: when computing vector element at index '1'
// :89:22: error: use of undefined value here causes illegal behavior
// :89:22: note: when computing vector element at index '1'
// :89:22: error: use of undefined value here causes illegal behavior
// :89:22: note: when computing vector element at index '0'
// :89:22: error: use of undefined value here causes illegal behavior
// :89:22: note: when computing vector element at index '0'
// :89:22: error: use of undefined value here causes illegal behavior
// :89:22: note: when computing vector element at index '0'
// :89:22: error: use of undefined value here causes illegal behavior
// :89:22: note: when computing vector element at index '0'
// :89:25: error: use of undefined value here causes illegal behavior
// :89:25: note: when computing vector element at index '0'
// :89:25: error: use of undefined value here causes illegal behavior
// :89:25: note: when computing vector element at index '0'
// :89:25: error: use of undefined value here causes illegal behavior
// :89:25: note: when computing vector element at index '0'
// :89:25: error: use of undefined value here causes illegal behavior
// :89:25: note: when computing vector element at index '0'
// :89:25: error: use of undefined value here causes illegal behavior
// :89:25: note: when computing vector element at index '0'
// :89:25: error: use of undefined value here causes illegal behavior
// :89:25: note: when computing vector element at index '0'
// :89:25: error: use of undefined value here causes illegal behavior
// :89:25: note: when computing vector element at index '0'
// :89:25: error: use of undefined value here causes illegal behavior
// :89:25: note: when computing vector element at index '0'
// :89:25: error: use of undefined value here causes illegal behavior
// :89:25: note: when computing vector element at index '0'
// :89:25: error: use of undefined value here causes illegal behavior
// :89:25: note: when computing vector element at index '0'
// :89:25: error: use of undefined value here causes illegal behavior
// :89:25: note: when computing vector element at index '0'
// :89:25: error: use of undefined value here causes illegal behavior
// :89:25: note: when computing vector element at index '0'
// :89:25: error: use of undefined value here causes illegal behavior
// :89:25: note: when computing vector element at index '0'
// :89:25: error: use of undefined value here causes illegal behavior
// :89:25: note: when computing vector element at index '0'
// :89:25: error: use of undefined value here causes illegal behavior
// :89:25: note: when computing vector element at index '0'
// :89:25: error: use of undefined value here causes illegal behavior
// :89:25: note: when computing vector element at index '0'
// :89:25: error: use of undefined value here causes illegal behavior
// :89:25: note: when computing vector element at index '0'
// :89:25: error: use of undefined value here causes illegal behavior
// :89:25: note: when computing vector element at index '0'
// :89:25: error: use of undefined value here causes illegal behavior
// :89:25: note: when computing vector element at index '0'
// :89:25: error: use of undefined value here causes illegal behavior
// :89:25: note: when computing vector element at index '0'
// :89:25: error: use of undefined value here causes illegal behavior
// :89:25: note: when computing vector element at index '0'
// :89:25: error: use of undefined value here causes illegal behavior
// :89:25: note: when computing vector element at index '0'
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: note: when computing vector element at index '1'
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: note: when computing vector element at index '1'
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: note: when computing vector element at index '1'
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: note: when computing vector element at index '1'
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: note: when computing vector element at index '0'
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: note: when computing vector element at index '0'
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: note: when computing vector element at index '0'
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: note: when computing vector element at index '0'
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: note: when computing vector element at index '1'
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: note: when computing vector element at index '1'
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: note: when computing vector element at index '1'
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: note: when computing vector element at index '1'
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: note: when computing vector element at index '0'
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: note: when computing vector element at index '0'
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: note: when computing vector element at index '0'
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: note: when computing vector element at index '0'
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: note: when computing vector element at index '1'
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: note: when computing vector element at index '1'
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: note: when computing vector element at index '1'
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: note: when computing vector element at index '1'
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: note: when computing vector element at index '0'
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: note: when computing vector element at index '0'
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: note: when computing vector element at index '0'
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: note: when computing vector element at index '0'
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: note: when computing vector element at index '1'
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: note: when computing vector element at index '1'
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: note: when computing vector element at index '1'
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: note: when computing vector element at index '1'
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: note: when computing vector element at index '0'
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: note: when computing vector element at index '0'
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: note: when computing vector element at index '0'
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: note: when computing vector element at index '0'
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: note: when computing vector element at index '1'
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: note: when computing vector element at index '1'
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: note: when computing vector element at index '1'
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: note: when computing vector element at index '1'
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: note: when computing vector element at index '0'
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: note: when computing vector element at index '0'
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: note: when computing vector element at index '0'
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: note: when computing vector element at index '0'
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: note: when computing vector element at index '1'
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: note: when computing vector element at index '1'
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: note: when computing vector element at index '1'
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: note: when computing vector element at index '1'
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: note: when computing vector element at index '0'
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: note: when computing vector element at index '0'
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: note: when computing vector element at index '0'
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: note: when computing vector element at index '0'
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: note: when computing vector element at index '1'
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: note: when computing vector element at index '1'
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: note: when computing vector element at index '1'
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: note: when computing vector element at index '1'
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: note: when computing vector element at index '0'
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: note: when computing vector element at index '0'
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: note: when computing vector element at index '0'
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: note: when computing vector element at index '0'
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: note: when computing vector element at index '1'
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: note: when computing vector element at index '1'
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: note: when computing vector element at index '1'
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: note: when computing vector element at index '1'
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: note: when computing vector element at index '0'
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: note: when computing vector element at index '0'
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: note: when computing vector element at index '0'
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: note: when computing vector element at index '0'
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: note: when computing vector element at index '1'
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: note: when computing vector element at index '1'
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: note: when computing vector element at index '1'
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: note: when computing vector element at index '1'
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: note: when computing vector element at index '0'
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: note: when computing vector element at index '0'
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: note: when computing vector element at index '0'
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: note: when computing vector element at index '0'
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: note: when computing vector element at index '1'
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: note: when computing vector element at index '1'
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: note: when computing vector element at index '1'
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: note: when computing vector element at index '1'
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: note: when computing vector element at index '0'
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: note: when computing vector element at index '0'
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: note: when computing vector element at index '0'
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: note: when computing vector element at index '0'
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: note: when computing vector element at index '1'
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: note: when computing vector element at index '1'
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: note: when computing vector element at index '1'
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: note: when computing vector element at index '1'
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: note: when computing vector element at index '0'
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: note: when computing vector element at index '0'
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: note: when computing vector element at index '0'
// :95:17: error: use of undefined value here causes illegal behavior
// :95:17: note: when computing vector element at index '0'
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: note: when computing vector element at index '1'
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: note: when computing vector element at index '1'
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: note: when computing vector element at index '1'
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: note: when computing vector element at index '1'
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: note: when computing vector element at index '0'
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: note: when computing vector element at index '0'
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: note: when computing vector element at index '0'
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: note: when computing vector element at index '0'
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: note: when computing vector element at index '1'
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: note: when computing vector element at index '1'
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: note: when computing vector element at index '1'
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: note: when computing vector element at index '1'
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: note: when computing vector element at index '0'
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: note: when computing vector element at index '0'
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: note: when computing vector element at index '0'
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: note: when computing vector element at index '0'
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: note: when computing vector element at index '1'
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: note: when computing vector element at index '1'
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: note: when computing vector element at index '1'
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: note: when computing vector element at index '1'
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: note: when computing vector element at index '0'
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: note: when computing vector element at index '0'
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: note: when computing vector element at index '0'
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: note: when computing vector element at index '0'
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: note: when computing vector element at index '1'
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: note: when computing vector element at index '1'
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: note: when computing vector element at index '1'
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: note: when computing vector element at index '1'
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: note: when computing vector element at index '0'
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: note: when computing vector element at index '0'
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: note: when computing vector element at index '0'
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: note: when computing vector element at index '0'
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: note: when computing vector element at index '1'
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: note: when computing vector element at index '1'
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: note: when computing vector element at index '1'
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: note: when computing vector element at index '1'
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: note: when computing vector element at index '0'
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: note: when computing vector element at index '0'
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: note: when computing vector element at index '0'
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: note: when computing vector element at index '0'
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: note: when computing vector element at index '1'
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: note: when computing vector element at index '1'
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: note: when computing vector element at index '1'
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: note: when computing vector element at index '1'
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: note: when computing vector element at index '0'
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: note: when computing vector element at index '0'
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: note: when computing vector element at index '0'
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: note: when computing vector element at index '0'
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: note: when computing vector element at index '1'
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: note: when computing vector element at index '1'
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: note: when computing vector element at index '1'
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: note: when computing vector element at index '1'
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: note: when computing vector element at index '0'
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: note: when computing vector element at index '0'
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: note: when computing vector element at index '0'
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: note: when computing vector element at index '0'
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: note: when computing vector element at index '1'
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: note: when computing vector element at index '1'
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: note: when computing vector element at index '1'
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: note: when computing vector element at index '1'
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: note: when computing vector element at index '0'
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: note: when computing vector element at index '0'
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: note: when computing vector element at index '0'
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: note: when computing vector element at index '0'
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: note: when computing vector element at index '1'
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: note: when computing vector element at index '1'
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: note: when computing vector element at index '1'
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: note: when computing vector element at index '1'
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: note: when computing vector element at index '0'
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: note: when computing vector element at index '0'
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: note: when computing vector element at index '0'
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: note: when computing vector element at index '0'
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: note: when computing vector element at index '1'
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: note: when computing vector element at index '1'
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: note: when computing vector element at index '1'
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: note: when computing vector element at index '1'
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: note: when computing vector element at index '0'
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: note: when computing vector element at index '0'
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: note: when computing vector element at index '0'
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: note: when computing vector element at index '0'
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: note: when computing vector element at index '1'
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: note: when computing vector element at index '1'
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: note: when computing vector element at index '1'
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: note: when computing vector element at index '1'
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: note: when computing vector element at index '0'
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: note: when computing vector element at index '0'
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: note: when computing vector element at index '0'
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: note: when computing vector element at index '0'
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: note: when computing vector element at index '1'
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: note: when computing vector element at index '1'
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: note: when computing vector element at index '1'
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: note: when computing vector element at index '1'
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: note: when computing vector element at index '0'
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: note: when computing vector element at index '0'
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: note: when computing vector element at index '0'
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: note: when computing vector element at index '0'
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: note: when computing vector element at index '1'
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: note: when computing vector element at index '1'
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: note: when computing vector element at index '1'
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: note: when computing vector element at index '1'
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: note: when computing vector element at index '0'
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: note: when computing vector element at index '0'
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: note: when computing vector element at index '0'
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: note: when computing vector element at index '0'
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: note: when computing vector element at index '1'
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: note: when computing vector element at index '1'
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: note: when computing vector element at index '1'
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: note: when computing vector element at index '1'
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: note: when computing vector element at index '0'
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: note: when computing vector element at index '0'
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: note: when computing vector element at index '0'
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: note: when computing vector element at index '0'
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: note: when computing vector element at index '1'
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: note: when computing vector element at index '1'
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: note: when computing vector element at index '1'
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: note: when computing vector element at index '1'
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: note: when computing vector element at index '0'
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: note: when computing vector element at index '0'
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: note: when computing vector element at index '0'
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: note: when computing vector element at index '0'
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: note: when computing vector element at index '1'
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: note: when computing vector element at index '1'
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: note: when computing vector element at index '1'
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: note: when computing vector element at index '1'
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: note: when computing vector element at index '0'
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: note: when computing vector element at index '0'
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: note: when computing vector element at index '0'
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: note: when computing vector element at index '0'
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: note: when computing vector element at index '1'
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: note: when computing vector element at index '1'
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: note: when computing vector element at index '1'
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: note: when computing vector element at index '1'
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: note: when computing vector element at index '0'
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: note: when computing vector element at index '0'
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: note: when computing vector element at index '0'
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: note: when computing vector element at index '0'
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: note: when computing vector element at index '1'
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: note: when computing vector element at index '1'
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: note: when computing vector element at index '1'
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: note: when computing vector element at index '1'
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: note: when computing vector element at index '0'
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: note: when computing vector element at index '0'
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: note: when computing vector element at index '0'
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: note: when computing vector element at index '0'
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: note: when computing vector element at index '1'
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: note: when computing vector element at index '1'
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: note: when computing vector element at index '1'
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: note: when computing vector element at index '1'
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: note: when computing vector element at index '0'
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: note: when computing vector element at index '0'
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: note: when computing vector element at index '0'
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: note: when computing vector element at index '0'
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: note: when computing vector element at index '1'
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: note: when computing vector element at index '1'
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: note: when computing vector element at index '1'
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: note: when computing vector element at index '1'
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: note: when computing vector element at index '0'
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: note: when computing vector element at index '0'
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: note: when computing vector element at index '0'
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: note: when computing vector element at index '0'
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: note: when computing vector element at index '1'
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: note: when computing vector element at index '1'
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: note: when computing vector element at index '1'
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: note: when computing vector element at index '1'
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: note: when computing vector element at index '0'
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: note: when computing vector element at index '0'
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: note: when computing vector element at index '0'
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: note: when computing vector element at index '0'
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: note: when computing vector element at index '1'
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: note: when computing vector element at index '1'
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: note: when computing vector element at index '1'
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: note: when computing vector element at index '1'
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: note: when computing vector element at index '0'
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: note: when computing vector element at index '0'
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: note: when computing vector element at index '0'
// :103:27: error: use of undefined value here causes illegal behavior
// :103:27: note: when computing vector element at index '0'
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: note: when computing vector element at index '1'
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: note: when computing vector element at index '1'
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: note: when computing vector element at index '1'
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: note: when computing vector element at index '1'
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: note: when computing vector element at index '0'
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: note: when computing vector element at index '0'
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: note: when computing vector element at index '0'
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: note: when computing vector element at index '0'
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: note: when computing vector element at index '1'
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: note: when computing vector element at index '1'
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: note: when computing vector element at index '1'
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: note: when computing vector element at index '1'
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: note: when computing vector element at index '0'
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: note: when computing vector element at index '0'
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: note: when computing vector element at index '0'
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: note: when computing vector element at index '0'
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: note: when computing vector element at index '1'
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: note: when computing vector element at index '1'
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: note: when computing vector element at index '1'
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: note: when computing vector element at index '1'
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: note: when computing vector element at index '0'
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: note: when computing vector element at index '0'
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: note: when computing vector element at index '0'
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: note: when computing vector element at index '0'
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: note: when computing vector element at index '1'
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: note: when computing vector element at index '1'
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: note: when computing vector element at index '1'
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: note: when computing vector element at index '1'
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: note: when computing vector element at index '0'
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: note: when computing vector element at index '0'
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: note: when computing vector element at index '0'
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: note: when computing vector element at index '0'
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: note: when computing vector element at index '1'
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: note: when computing vector element at index '1'
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: note: when computing vector element at index '1'
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: note: when computing vector element at index '1'
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: note: when computing vector element at index '0'
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: note: when computing vector element at index '0'
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: note: when computing vector element at index '0'
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: note: when computing vector element at index '0'
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: note: when computing vector element at index '1'
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: note: when computing vector element at index '1'
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: note: when computing vector element at index '1'
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: note: when computing vector element at index '1'
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: note: when computing vector element at index '0'
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: note: when computing vector element at index '0'
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: note: when computing vector element at index '0'
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: note: when computing vector element at index '0'
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: note: when computing vector element at index '1'
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: note: when computing vector element at index '1'
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: note: when computing vector element at index '1'
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: note: when computing vector element at index '1'
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: note: when computing vector element at index '0'
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: note: when computing vector element at index '0'
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: note: when computing vector element at index '0'
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: note: when computing vector element at index '0'
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: note: when computing vector element at index '1'
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: note: when computing vector element at index '1'
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: note: when computing vector element at index '1'
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: note: when computing vector element at index '1'
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: note: when computing vector element at index '0'
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: note: when computing vector element at index '0'
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: note: when computing vector element at index '0'
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: note: when computing vector element at index '0'
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: note: when computing vector element at index '1'
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: note: when computing vector element at index '1'
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: note: when computing vector element at index '1'
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: note: when computing vector element at index '1'
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: note: when computing vector element at index '0'
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: note: when computing vector element at index '0'
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: note: when computing vector element at index '0'
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: note: when computing vector element at index '0'
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: note: when computing vector element at index '1'
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: note: when computing vector element at index '1'
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: note: when computing vector element at index '1'
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: note: when computing vector element at index '1'
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: note: when computing vector element at index '0'
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: note: when computing vector element at index '0'
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: note: when computing vector element at index '0'
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: note: when computing vector element at index '0'
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: note: when computing vector element at index '1'
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: note: when computing vector element at index '1'
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: note: when computing vector element at index '1'
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: note: when computing vector element at index '1'
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: note: when computing vector element at index '0'
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: note: when computing vector element at index '0'
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: note: when computing vector element at index '0'
// :107:27: error: use of undefined value here causes illegal behavior
// :107:27: note: when computing vector element at index '0'
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: note: when computing vector element at index '1'
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: note: when computing vector element at index '1'
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: note: when computing vector element at index '1'
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: note: when computing vector element at index '1'
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: note: when computing vector element at index '0'
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: note: when computing vector element at index '0'
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: note: when computing vector element at index '0'
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: note: when computing vector element at index '0'
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: note: when computing vector element at index '1'
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: note: when computing vector element at index '1'
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: note: when computing vector element at index '1'
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: note: when computing vector element at index '1'
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: note: when computing vector element at index '0'
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: note: when computing vector element at index '0'
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: note: when computing vector element at index '0'
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: note: when computing vector element at index '0'
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: note: when computing vector element at index '1'
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: note: when computing vector element at index '1'
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: note: when computing vector element at index '1'
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: note: when computing vector element at index '1'
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: note: when computing vector element at index '0'
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: note: when computing vector element at index '0'
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: note: when computing vector element at index '0'
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: note: when computing vector element at index '0'
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: note: when computing vector element at index '1'
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: note: when computing vector element at index '1'
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: note: when computing vector element at index '1'
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: note: when computing vector element at index '1'
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: note: when computing vector element at index '0'
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: note: when computing vector element at index '0'
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: note: when computing vector element at index '0'
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: note: when computing vector element at index '0'
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: note: when computing vector element at index '1'
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: note: when computing vector element at index '1'
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: note: when computing vector element at index '1'
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: note: when computing vector element at index '1'
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: note: when computing vector element at index '0'
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: note: when computing vector element at index '0'
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: note: when computing vector element at index '0'
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: note: when computing vector element at index '0'
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: note: when computing vector element at index '1'
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: note: when computing vector element at index '1'
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: note: when computing vector element at index '1'
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: note: when computing vector element at index '1'
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: note: when computing vector element at index '0'
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: note: when computing vector element at index '0'
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: note: when computing vector element at index '0'
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: note: when computing vector element at index '0'
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: note: when computing vector element at index '1'
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: note: when computing vector element at index '1'
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: note: when computing vector element at index '1'
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: note: when computing vector element at index '1'
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: note: when computing vector element at index '0'
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: note: when computing vector element at index '0'
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: note: when computing vector element at index '0'
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: note: when computing vector element at index '0'
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: note: when computing vector element at index '1'
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: note: when computing vector element at index '1'
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: note: when computing vector element at index '1'
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: note: when computing vector element at index '1'
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: note: when computing vector element at index '0'
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: note: when computing vector element at index '0'
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: note: when computing vector element at index '0'
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: note: when computing vector element at index '0'
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: note: when computing vector element at index '1'
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: note: when computing vector element at index '1'
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: note: when computing vector element at index '1'
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: note: when computing vector element at index '1'
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: note: when computing vector element at index '0'
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: note: when computing vector element at index '0'
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: note: when computing vector element at index '0'
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: note: when computing vector element at index '0'
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: note: when computing vector element at index '1'
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: note: when computing vector element at index '1'
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: note: when computing vector element at index '1'
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: note: when computing vector element at index '1'
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: note: when computing vector element at index '0'
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: note: when computing vector element at index '0'
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: note: when computing vector element at index '0'
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: note: when computing vector element at index '0'
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: note: when computing vector element at index '1'
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: note: when computing vector element at index '1'
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: note: when computing vector element at index '1'
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: note: when computing vector element at index '1'
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: note: when computing vector element at index '0'
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: note: when computing vector element at index '0'
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: note: when computing vector element at index '0'
// :111:22: error: use of undefined value here causes illegal behavior
// :111:22: note: when computing vector element at index '0'
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: note: when computing vector element at index '1'
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: note: when computing vector element at index '1'
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: note: when computing vector element at index '1'
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: note: when computing vector element at index '1'
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: note: when computing vector element at index '0'
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: note: when computing vector element at index '0'
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: note: when computing vector element at index '0'
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: note: when computing vector element at index '0'
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: note: when computing vector element at index '1'
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: note: when computing vector element at index '1'
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: note: when computing vector element at index '1'
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: note: when computing vector element at index '1'
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: note: when computing vector element at index '0'
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: note: when computing vector element at index '0'
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: note: when computing vector element at index '0'
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: note: when computing vector element at index '0'
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: note: when computing vector element at index '1'
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: note: when computing vector element at index '1'
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: note: when computing vector element at index '1'
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: note: when computing vector element at index '1'
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: note: when computing vector element at index '0'
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: note: when computing vector element at index '0'
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: note: when computing vector element at index '0'
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: note: when computing vector element at index '0'
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: note: when computing vector element at index '1'
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: note: when computing vector element at index '1'
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: note: when computing vector element at index '1'
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: note: when computing vector element at index '1'
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: note: when computing vector element at index '0'
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: note: when computing vector element at index '0'
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: note: when computing vector element at index '0'
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: note: when computing vector element at index '0'
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: note: when computing vector element at index '1'
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: note: when computing vector element at index '1'
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: note: when computing vector element at index '1'
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: note: when computing vector element at index '1'
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: note: when computing vector element at index '0'
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: note: when computing vector element at index '0'
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: note: when computing vector element at index '0'
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: note: when computing vector element at index '0'
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: note: when computing vector element at index '1'
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: note: when computing vector element at index '1'
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: note: when computing vector element at index '1'
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: note: when computing vector element at index '1'
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: note: when computing vector element at index '0'
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: note: when computing vector element at index '0'
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: note: when computing vector element at index '0'
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: note: when computing vector element at index '0'
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: note: when computing vector element at index '1'
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: note: when computing vector element at index '1'
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: note: when computing vector element at index '1'
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: note: when computing vector element at index '1'
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: note: when computing vector element at index '0'
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: note: when computing vector element at index '0'
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: note: when computing vector element at index '0'
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: note: when computing vector element at index '0'
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: note: when computing vector element at index '1'
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: note: when computing vector element at index '1'
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: note: when computing vector element at index '1'
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: note: when computing vector element at index '1'
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: note: when computing vector element at index '0'
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: note: when computing vector element at index '0'
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: note: when computing vector element at index '0'
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: note: when computing vector element at index '0'
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: note: when computing vector element at index '1'
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: note: when computing vector element at index '1'
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: note: when computing vector element at index '1'
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: note: when computing vector element at index '1'
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: note: when computing vector element at index '0'
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: note: when computing vector element at index '0'
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: note: when computing vector element at index '0'
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: note: when computing vector element at index '0'
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: note: when computing vector element at index '1'
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: note: when computing vector element at index '1'
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: note: when computing vector element at index '1'
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: note: when computing vector element at index '1'
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: note: when computing vector element at index '0'
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: note: when computing vector element at index '0'
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: note: when computing vector element at index '0'
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: note: when computing vector element at index '0'
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: note: when computing vector element at index '1'
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: note: when computing vector element at index '1'
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: note: when computing vector element at index '1'
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: note: when computing vector element at index '1'
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: note: when computing vector element at index '0'
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: note: when computing vector element at index '0'
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: note: when computing vector element at index '0'
// :115:22: error: use of undefined value here causes illegal behavior
// :115:22: note: when computing vector element at index '0'
// :121:17: error: use of undefined value here causes illegal behavior
// :121:17: error: use of undefined value here causes illegal behavior
// :121:17: note: when computing vector element at index '0'
// :121:17: error: use of undefined value here causes illegal behavior
// :121:17: note: when computing vector element at index '0'
// :121:17: error: use of undefined value here causes illegal behavior
// :121:17: note: when computing vector element at index '0'
// :121:17: error: use of undefined value here causes illegal behavior
// :121:17: note: when computing vector element at index '1'
// :121:17: error: use of undefined value here causes illegal behavior
// :121:17: note: when computing vector element at index '0'
// :121:17: error: use of undefined value here causes illegal behavior
// :121:17: note: when computing vector element at index '0'
// :121:17: error: use of undefined value here causes illegal behavior
// :121:17: note: when computing vector element at index '0'
// :121:17: error: use of undefined value here causes illegal behavior
// :121:17: error: use of undefined value here causes illegal behavior
// :121:17: note: when computing vector element at index '0'
// :121:17: error: use of undefined value here causes illegal behavior
// :121:17: note: when computing vector element at index '0'
// :121:17: error: use of undefined value here causes illegal behavior
// :121:17: note: when computing vector element at index '0'
// :121:17: error: use of undefined value here causes illegal behavior
// :121:17: note: when computing vector element at index '1'
// :121:17: error: use of undefined value here causes illegal behavior
// :121:17: note: when computing vector element at index '0'
// :121:17: error: use of undefined value here causes illegal behavior
// :121:17: note: when computing vector element at index '0'
// :121:17: error: use of undefined value here causes illegal behavior
// :121:17: note: when computing vector element at index '0'
// :121:17: error: use of undefined value here causes illegal behavior
// :121:17: error: use of undefined value here causes illegal behavior
// :121:17: note: when computing vector element at index '0'
// :121:17: error: use of undefined value here causes illegal behavior
// :121:17: note: when computing vector element at index '0'
// :121:17: error: use of undefined value here causes illegal behavior
// :121:17: note: when computing vector element at index '0'
// :121:17: error: use of undefined value here causes illegal behavior
// :121:17: note: when computing vector element at index '1'
// :121:17: error: use of undefined value here causes illegal behavior
// :121:17: note: when computing vector element at index '0'
// :121:17: error: use of undefined value here causes illegal behavior
// :121:17: note: when computing vector element at index '0'
// :121:17: error: use of undefined value here causes illegal behavior
// :121:17: note: when computing vector element at index '0'
// :121:17: error: use of undefined value here causes illegal behavior
// :121:17: error: use of undefined value here causes illegal behavior
// :121:17: note: when computing vector element at index '0'
// :121:17: error: use of undefined value here causes illegal behavior
// :121:17: note: when computing vector element at index '0'
// :121:17: error: use of undefined value here causes illegal behavior
// :121:17: note: when computing vector element at index '0'
// :121:17: error: use of undefined value here causes illegal behavior
// :121:17: note: when computing vector element at index '1'
// :121:17: error: use of undefined value here causes illegal behavior
// :121:17: note: when computing vector element at index '0'
// :121:17: error: use of undefined value here causes illegal behavior
// :121:17: note: when computing vector element at index '0'
// :121:17: error: use of undefined value here causes illegal behavior
// :121:17: note: when computing vector element at index '0'
// :121:17: error: use of undefined value here causes illegal behavior
// :121:17: error: use of undefined value here causes illegal behavior
// :121:17: note: when computing vector element at index '0'
// :121:17: error: use of undefined value here causes illegal behavior
// :121:17: note: when computing vector element at index '0'
// :121:17: error: use of undefined value here causes illegal behavior
// :121:17: note: when computing vector element at index '0'
// :121:17: error: use of undefined value here causes illegal behavior
// :121:17: note: when computing vector element at index '1'
// :121:17: error: use of undefined value here causes illegal behavior
// :121:17: note: when computing vector element at index '0'
// :121:17: error: use of undefined value here causes illegal behavior
// :121:17: note: when computing vector element at index '0'
// :121:17: error: use of undefined value here causes illegal behavior
// :121:17: note: when computing vector element at index '0'
// :121:17: error: use of undefined value here causes illegal behavior
// :121:17: error: use of undefined value here causes illegal behavior
// :121:17: note: when computing vector element at index '0'
// :121:17: error: use of undefined value here causes illegal behavior
// :121:17: note: when computing vector element at index '0'
// :121:17: error: use of undefined value here causes illegal behavior
// :121:17: note: when computing vector element at index '0'
// :121:17: error: use of undefined value here causes illegal behavior
// :121:17: note: when computing vector element at index '1'
// :121:17: error: use of undefined value here causes illegal behavior
// :121:17: note: when computing vector element at index '0'
// :121:17: error: use of undefined value here causes illegal behavior
// :121:17: note: when computing vector element at index '0'
// :121:17: error: use of undefined value here causes illegal behavior
// :121:17: note: when computing vector element at index '0'
// :121:17: error: use of undefined value here causes illegal behavior
// :121:17: error: use of undefined value here causes illegal behavior
// :121:17: note: when computing vector element at index '0'
// :121:17: error: use of undefined value here causes illegal behavior
// :121:17: note: when computing vector element at index '0'
// :121:17: error: use of undefined value here causes illegal behavior
// :121:17: note: when computing vector element at index '0'
// :121:17: error: use of undefined value here causes illegal behavior
// :121:17: note: when computing vector element at index '1'
// :121:17: error: use of undefined value here causes illegal behavior
// :121:17: note: when computing vector element at index '0'
// :121:17: error: use of undefined value here causes illegal behavior
// :121:17: note: when computing vector element at index '0'
// :121:17: error: use of undefined value here causes illegal behavior
// :121:17: note: when computing vector element at index '0'
// :121:17: error: use of undefined value here causes illegal behavior
// :121:17: error: use of undefined value here causes illegal behavior
// :121:17: note: when computing vector element at index '0'
// :121:17: error: use of undefined value here causes illegal behavior
// :121:17: note: when computing vector element at index '0'
// :121:17: error: use of undefined value here causes illegal behavior
// :121:17: note: when computing vector element at index '0'
// :121:17: error: use of undefined value here causes illegal behavior
// :121:17: note: when computing vector element at index '1'
// :121:17: error: use of undefined value here causes illegal behavior
// :121:17: note: when computing vector element at index '0'
// :121:17: error: use of undefined value here causes illegal behavior
// :121:17: note: when computing vector element at index '0'
// :121:17: error: use of undefined value here causes illegal behavior
// :121:17: note: when computing vector element at index '0'
// :121:17: error: use of undefined value here causes illegal behavior
// :121:17: error: use of undefined value here causes illegal behavior
// :121:17: note: when computing vector element at index '0'
// :121:17: error: use of undefined value here causes illegal behavior
// :121:17: note: when computing vector element at index '0'
// :121:17: error: use of undefined value here causes illegal behavior
// :121:17: note: when computing vector element at index '0'
// :121:17: error: use of undefined value here causes illegal behavior
// :121:17: note: when computing vector element at index '1'
// :121:17: error: use of undefined value here causes illegal behavior
// :121:17: note: when computing vector element at index '0'
// :121:17: error: use of undefined value here causes illegal behavior
// :121:17: note: when computing vector element at index '0'
// :121:17: error: use of undefined value here causes illegal behavior
// :121:17: note: when computing vector element at index '0'
// :121:17: error: use of undefined value here causes illegal behavior
// :121:17: error: use of undefined value here causes illegal behavior
// :121:17: note: when computing vector element at index '0'
// :121:17: error: use of undefined value here causes illegal behavior
// :121:17: note: when computing vector element at index '0'
// :121:17: error: use of undefined value here causes illegal behavior
// :121:17: note: when computing vector element at index '0'
// :121:17: error: use of undefined value here causes illegal behavior
// :121:17: note: when computing vector element at index '1'
// :121:17: error: use of undefined value here causes illegal behavior
// :121:17: note: when computing vector element at index '0'
// :121:17: error: use of undefined value here causes illegal behavior
// :121:17: note: when computing vector element at index '0'
// :121:17: error: use of undefined value here causes illegal behavior
// :121:17: note: when computing vector element at index '0'
// :121:17: error: use of undefined value here causes illegal behavior
// :121:17: error: use of undefined value here causes illegal behavior
// :121:17: note: when computing vector element at index '0'
// :121:17: error: use of undefined value here causes illegal behavior
// :121:17: note: when computing vector element at index '0'
// :121:17: error: use of undefined value here causes illegal behavior
// :121:17: note: when computing vector element at index '0'
// :121:17: error: use of undefined value here causes illegal behavior
// :121:17: note: when computing vector element at index '1'
// :121:17: error: use of undefined value here causes illegal behavior
// :121:17: note: when computing vector element at index '0'
// :121:17: error: use of undefined value here causes illegal behavior
// :121:17: note: when computing vector element at index '0'
// :121:17: error: use of undefined value here causes illegal behavior
// :121:17: note: when computing vector element at index '0'
// :121:21: error: use of undefined value here causes illegal behavior
// :121:21: error: use of undefined value here causes illegal behavior
// :121:21: note: when computing vector element at index '0'
// :121:21: error: use of undefined value here causes illegal behavior
// :121:21: note: when computing vector element at index '0'
// :121:21: error: use of undefined value here causes illegal behavior
// :121:21: note: when computing vector element at index '1'
// :121:21: error: use of undefined value here causes illegal behavior
// :121:21: note: when computing vector element at index '0'
// :121:21: error: use of undefined value here causes illegal behavior
// :121:21: note: when computing vector element at index '0'
// :121:21: error: use of undefined value here causes illegal behavior
// :121:21: error: use of undefined value here causes illegal behavior
// :121:21: note: when computing vector element at index '0'
// :121:21: error: use of undefined value here causes illegal behavior
// :121:21: note: when computing vector element at index '0'
// :121:21: error: use of undefined value here causes illegal behavior
// :121:21: note: when computing vector element at index '1'
// :121:21: error: use of undefined value here causes illegal behavior
// :121:21: note: when computing vector element at index '0'
// :121:21: error: use of undefined value here causes illegal behavior
// :121:21: note: when computing vector element at index '0'
// :121:21: error: use of undefined value here causes illegal behavior
// :121:21: error: use of undefined value here causes illegal behavior
// :121:21: note: when computing vector element at index '0'
// :121:21: error: use of undefined value here causes illegal behavior
// :121:21: note: when computing vector element at index '0'
// :121:21: error: use of undefined value here causes illegal behavior
// :121:21: note: when computing vector element at index '1'
// :121:21: error: use of undefined value here causes illegal behavior
// :121:21: note: when computing vector element at index '0'
// :121:21: error: use of undefined value here causes illegal behavior
// :121:21: note: when computing vector element at index '0'
// :121:21: error: use of undefined value here causes illegal behavior
// :121:21: error: use of undefined value here causes illegal behavior
// :121:21: note: when computing vector element at index '0'
// :121:21: error: use of undefined value here causes illegal behavior
// :121:21: note: when computing vector element at index '0'
// :121:21: error: use of undefined value here causes illegal behavior
// :121:21: note: when computing vector element at index '1'
// :121:21: error: use of undefined value here causes illegal behavior
// :121:21: note: when computing vector element at index '0'
// :121:21: error: use of undefined value here causes illegal behavior
// :121:21: note: when computing vector element at index '0'
// :121:21: error: use of undefined value here causes illegal behavior
// :121:21: error: use of undefined value here causes illegal behavior
// :121:21: note: when computing vector element at index '0'
// :121:21: error: use of undefined value here causes illegal behavior
// :121:21: note: when computing vector element at index '0'
// :121:21: error: use of undefined value here causes illegal behavior
// :121:21: note: when computing vector element at index '1'
// :121:21: error: use of undefined value here causes illegal behavior
// :121:21: note: when computing vector element at index '0'
// :121:21: error: use of undefined value here causes illegal behavior
// :121:21: note: when computing vector element at index '0'
// :121:21: error: use of undefined value here causes illegal behavior
// :121:21: error: use of undefined value here causes illegal behavior
// :121:21: note: when computing vector element at index '0'
// :121:21: error: use of undefined value here causes illegal behavior
// :121:21: note: when computing vector element at index '0'
// :121:21: error: use of undefined value here causes illegal behavior
// :121:21: note: when computing vector element at index '1'
// :121:21: error: use of undefined value here causes illegal behavior
// :121:21: note: when computing vector element at index '0'
// :121:21: error: use of undefined value here causes illegal behavior
// :121:21: note: when computing vector element at index '0'
// :121:21: error: use of undefined value here causes illegal behavior
// :121:21: error: use of undefined value here causes illegal behavior
// :121:21: note: when computing vector element at index '0'
// :121:21: error: use of undefined value here causes illegal behavior
// :121:21: note: when computing vector element at index '0'
// :121:21: error: use of undefined value here causes illegal behavior
// :121:21: note: when computing vector element at index '1'
// :121:21: error: use of undefined value here causes illegal behavior
// :121:21: note: when computing vector element at index '0'
// :121:21: error: use of undefined value here causes illegal behavior
// :121:21: note: when computing vector element at index '0'
// :121:21: error: use of undefined value here causes illegal behavior
// :121:21: error: use of undefined value here causes illegal behavior
// :121:21: note: when computing vector element at index '0'
// :121:21: error: use of undefined value here causes illegal behavior
// :121:21: note: when computing vector element at index '0'
// :121:21: error: use of undefined value here causes illegal behavior
// :121:21: note: when computing vector element at index '1'
// :121:21: error: use of undefined value here causes illegal behavior
// :121:21: note: when computing vector element at index '0'
// :121:21: error: use of undefined value here causes illegal behavior
// :121:21: note: when computing vector element at index '0'
// :121:21: error: use of undefined value here causes illegal behavior
// :121:21: error: use of undefined value here causes illegal behavior
// :121:21: note: when computing vector element at index '0'
// :121:21: error: use of undefined value here causes illegal behavior
// :121:21: note: when computing vector element at index '0'
// :121:21: error: use of undefined value here causes illegal behavior
// :121:21: note: when computing vector element at index '1'
// :121:21: error: use of undefined value here causes illegal behavior
// :121:21: note: when computing vector element at index '0'
// :121:21: error: use of undefined value here causes illegal behavior
// :121:21: note: when computing vector element at index '0'
// :121:21: error: use of undefined value here causes illegal behavior
// :121:21: error: use of undefined value here causes illegal behavior
// :121:21: note: when computing vector element at index '0'
// :121:21: error: use of undefined value here causes illegal behavior
// :121:21: note: when computing vector element at index '0'
// :121:21: error: use of undefined value here causes illegal behavior
// :121:21: note: when computing vector element at index '1'
// :121:21: error: use of undefined value here causes illegal behavior
// :121:21: note: when computing vector element at index '0'
// :121:21: error: use of undefined value here causes illegal behavior
// :121:21: note: when computing vector element at index '0'
// :121:21: error: use of undefined value here causes illegal behavior
// :121:21: error: use of undefined value here causes illegal behavior
// :121:21: note: when computing vector element at index '0'
// :121:21: error: use of undefined value here causes illegal behavior
// :121:21: note: when computing vector element at index '0'
// :121:21: error: use of undefined value here causes illegal behavior
// :121:21: note: when computing vector element at index '1'
// :121:21: error: use of undefined value here causes illegal behavior
// :121:21: note: when computing vector element at index '0'
// :121:21: error: use of undefined value here causes illegal behavior
// :121:21: note: when computing vector element at index '0'
// :125:27: error: use of undefined value here causes illegal behavior
// :125:27: error: use of undefined value here causes illegal behavior
// :125:27: note: when computing vector element at index '0'
// :125:27: error: use of undefined value here causes illegal behavior
// :125:27: note: when computing vector element at index '0'
// :125:27: error: use of undefined value here causes illegal behavior
// :125:27: note: when computing vector element at index '0'
// :125:27: error: use of undefined value here causes illegal behavior
// :125:27: note: when computing vector element at index '1'
// :125:27: error: use of undefined value here causes illegal behavior
// :125:27: note: when computing vector element at index '0'
// :125:27: error: use of undefined value here causes illegal behavior
// :125:27: note: when computing vector element at index '0'
// :125:27: error: use of undefined value here causes illegal behavior
// :125:27: note: when computing vector element at index '0'
// :125:27: error: use of undefined value here causes illegal behavior
// :125:27: error: use of undefined value here causes illegal behavior
// :125:27: note: when computing vector element at index '0'
// :125:27: error: use of undefined value here causes illegal behavior
// :125:27: note: when computing vector element at index '0'
// :125:27: error: use of undefined value here causes illegal behavior
// :125:27: note: when computing vector element at index '0'
// :125:27: error: use of undefined value here causes illegal behavior
// :125:27: note: when computing vector element at index '1'
// :125:27: error: use of undefined value here causes illegal behavior
// :125:27: note: when computing vector element at index '0'
// :125:27: error: use of undefined value here causes illegal behavior
// :125:27: note: when computing vector element at index '0'
// :125:27: error: use of undefined value here causes illegal behavior
// :125:27: note: when computing vector element at index '0'
// :125:27: error: use of undefined value here causes illegal behavior
// :125:27: error: use of undefined value here causes illegal behavior
// :125:27: note: when computing vector element at index '0'
// :125:27: error: use of undefined value here causes illegal behavior
// :125:27: note: when computing vector element at index '0'
// :125:27: error: use of undefined value here causes illegal behavior
// :125:27: note: when computing vector element at index '0'
// :125:27: error: use of undefined value here causes illegal behavior
// :125:27: note: when computing vector element at index '1'
// :125:27: error: use of undefined value here causes illegal behavior
// :125:27: note: when computing vector element at index '0'
// :125:27: error: use of undefined value here causes illegal behavior
// :125:27: note: when computing vector element at index '0'
// :125:27: error: use of undefined value here causes illegal behavior
// :125:27: note: when computing vector element at index '0'
// :125:27: error: use of undefined value here causes illegal behavior
// :125:27: error: use of undefined value here causes illegal behavior
// :125:27: note: when computing vector element at index '0'
// :125:27: error: use of undefined value here causes illegal behavior
// :125:27: note: when computing vector element at index '0'
// :125:27: error: use of undefined value here causes illegal behavior
// :125:27: note: when computing vector element at index '0'
// :125:27: error: use of undefined value here causes illegal behavior
// :125:27: note: when computing vector element at index '1'
// :125:27: error: use of undefined value here causes illegal behavior
// :125:27: note: when computing vector element at index '0'
// :125:27: error: use of undefined value here causes illegal behavior
// :125:27: note: when computing vector element at index '0'
// :125:27: error: use of undefined value here causes illegal behavior
// :125:27: note: when computing vector element at index '0'
// :125:27: error: use of undefined value here causes illegal behavior
// :125:27: error: use of undefined value here causes illegal behavior
// :125:27: note: when computing vector element at index '0'
// :125:27: error: use of undefined value here causes illegal behavior
// :125:27: note: when computing vector element at index '0'
// :125:27: error: use of undefined value here causes illegal behavior
// :125:27: note: when computing vector element at index '0'
// :125:27: error: use of undefined value here causes illegal behavior
// :125:27: note: when computing vector element at index '1'
// :125:27: error: use of undefined value here causes illegal behavior
// :125:27: note: when computing vector element at index '0'
// :125:27: error: use of undefined value here causes illegal behavior
// :125:27: note: when computing vector element at index '0'
// :125:27: error: use of undefined value here causes illegal behavior
// :125:27: note: when computing vector element at index '0'
// :125:27: error: use of undefined value here causes illegal behavior
// :125:27: error: use of undefined value here causes illegal behavior
// :125:27: note: when computing vector element at index '0'
// :125:27: error: use of undefined value here causes illegal behavior
// :125:27: note: when computing vector element at index '0'
// :125:27: error: use of undefined value here causes illegal behavior
// :125:27: note: when computing vector element at index '0'
// :125:27: error: use of undefined value here causes illegal behavior
// :125:27: note: when computing vector element at index '1'
// :125:27: error: use of undefined value here causes illegal behavior
// :125:27: note: when computing vector element at index '0'
// :125:27: error: use of undefined value here causes illegal behavior
// :125:27: note: when computing vector element at index '0'
// :125:27: error: use of undefined value here causes illegal behavior
// :125:27: note: when computing vector element at index '0'
// :125:27: error: use of undefined value here causes illegal behavior
// :125:27: error: use of undefined value here causes illegal behavior
// :125:27: note: when computing vector element at index '0'
// :125:27: error: use of undefined value here causes illegal behavior
// :125:27: note: when computing vector element at index '0'
// :125:27: error: use of undefined value here causes illegal behavior
// :125:27: note: when computing vector element at index '0'
// :125:27: error: use of undefined value here causes illegal behavior
// :125:27: note: when computing vector element at index '1'
// :125:27: error: use of undefined value here causes illegal behavior
// :125:27: note: when computing vector element at index '0'
// :125:27: error: use of undefined value here causes illegal behavior
// :125:27: note: when computing vector element at index '0'
// :125:27: error: use of undefined value here causes illegal behavior
// :125:27: note: when computing vector element at index '0'
// :125:27: error: use of undefined value here causes illegal behavior
// :125:27: error: use of undefined value here causes illegal behavior
// :125:27: note: when computing vector element at index '0'
// :125:27: error: use of undefined value here causes illegal behavior
// :125:27: note: when computing vector element at index '0'
// :125:27: error: use of undefined value here causes illegal behavior
// :125:27: note: when computing vector element at index '0'
// :125:27: error: use of undefined value here causes illegal behavior
// :125:27: note: when computing vector element at index '1'
// :125:27: error: use of undefined value here causes illegal behavior
// :125:27: note: when computing vector element at index '0'
// :125:27: error: use of undefined value here causes illegal behavior
// :125:27: note: when computing vector element at index '0'
// :125:27: error: use of undefined value here causes illegal behavior
// :125:27: note: when computing vector element at index '0'
// :125:27: error: use of undefined value here causes illegal behavior
// :125:27: error: use of undefined value here causes illegal behavior
// :125:27: note: when computing vector element at index '0'
// :125:27: error: use of undefined value here causes illegal behavior
// :125:27: note: when computing vector element at index '0'
// :125:27: error: use of undefined value here causes illegal behavior
// :125:27: note: when computing vector element at index '0'
// :125:27: error: use of undefined value here causes illegal behavior
// :125:27: note: when computing vector element at index '1'
// :125:27: error: use of undefined value here causes illegal behavior
// :125:27: note: when computing vector element at index '0'
// :125:27: error: use of undefined value here causes illegal behavior
// :125:27: note: when computing vector element at index '0'
// :125:27: error: use of undefined value here causes illegal behavior
// :125:27: note: when computing vector element at index '0'
// :125:27: error: use of undefined value here causes illegal behavior
// :125:27: error: use of undefined value here causes illegal behavior
// :125:27: note: when computing vector element at index '0'
// :125:27: error: use of undefined value here causes illegal behavior
// :125:27: note: when computing vector element at index '0'
// :125:27: error: use of undefined value here causes illegal behavior
// :125:27: note: when computing vector element at index '0'
// :125:27: error: use of undefined value here causes illegal behavior
// :125:27: note: when computing vector element at index '1'
// :125:27: error: use of undefined value here causes illegal behavior
// :125:27: note: when computing vector element at index '0'
// :125:27: error: use of undefined value here causes illegal behavior
// :125:27: note: when computing vector element at index '0'
// :125:27: error: use of undefined value here causes illegal behavior
// :125:27: note: when computing vector element at index '0'
// :125:27: error: use of undefined value here causes illegal behavior
// :125:27: error: use of undefined value here causes illegal behavior
// :125:27: note: when computing vector element at index '0'
// :125:27: error: use of undefined value here causes illegal behavior
// :125:27: note: when computing vector element at index '0'
// :125:27: error: use of undefined value here causes illegal behavior
// :125:27: note: when computing vector element at index '0'
// :125:27: error: use of undefined value here causes illegal behavior
// :125:27: note: when computing vector element at index '1'
// :125:27: error: use of undefined value here causes illegal behavior
// :125:27: note: when computing vector element at index '0'
// :125:27: error: use of undefined value here causes illegal behavior
// :125:27: note: when computing vector element at index '0'
// :125:27: error: use of undefined value here causes illegal behavior
// :125:27: note: when computing vector element at index '0'
// :125:30: error: use of undefined value here causes illegal behavior
// :125:30: error: use of undefined value here causes illegal behavior
// :125:30: note: when computing vector element at index '0'
// :125:30: error: use of undefined value here causes illegal behavior
// :125:30: note: when computing vector element at index '0'
// :125:30: error: use of undefined value here causes illegal behavior
// :125:30: note: when computing vector element at index '1'
// :125:30: error: use of undefined value here causes illegal behavior
// :125:30: note: when computing vector element at index '0'
// :125:30: error: use of undefined value here causes illegal behavior
// :125:30: note: when computing vector element at index '0'
// :125:30: error: use of undefined value here causes illegal behavior
// :125:30: error: use of undefined value here causes illegal behavior
// :125:30: note: when computing vector element at index '0'
// :125:30: error: use of undefined value here causes illegal behavior
// :125:30: note: when computing vector element at index '0'
// :125:30: error: use of undefined value here causes illegal behavior
// :125:30: note: when computing vector element at index '1'
// :125:30: error: use of undefined value here causes illegal behavior
// :125:30: note: when computing vector element at index '0'
// :125:30: error: use of undefined value here causes illegal behavior
// :125:30: note: when computing vector element at index '0'
// :125:30: error: use of undefined value here causes illegal behavior
// :125:30: error: use of undefined value here causes illegal behavior
// :125:30: note: when computing vector element at index '0'
// :125:30: error: use of undefined value here causes illegal behavior
// :125:30: note: when computing vector element at index '0'
// :125:30: error: use of undefined value here causes illegal behavior
// :125:30: note: when computing vector element at index '1'
// :125:30: error: use of undefined value here causes illegal behavior
// :125:30: note: when computing vector element at index '0'
// :125:30: error: use of undefined value here causes illegal behavior
// :125:30: note: when computing vector element at index '0'
// :125:30: error: use of undefined value here causes illegal behavior
// :125:30: error: use of undefined value here causes illegal behavior
// :125:30: note: when computing vector element at index '0'
// :125:30: error: use of undefined value here causes illegal behavior
// :125:30: note: when computing vector element at index '0'
// :125:30: error: use of undefined value here causes illegal behavior
// :125:30: note: when computing vector element at index '1'
// :125:30: error: use of undefined value here causes illegal behavior
// :125:30: note: when computing vector element at index '0'
// :125:30: error: use of undefined value here causes illegal behavior
// :125:30: note: when computing vector element at index '0'
// :125:30: error: use of undefined value here causes illegal behavior
// :125:30: error: use of undefined value here causes illegal behavior
// :125:30: note: when computing vector element at index '0'
// :125:30: error: use of undefined value here causes illegal behavior
// :125:30: note: when computing vector element at index '0'
// :125:30: error: use of undefined value here causes illegal behavior
// :125:30: note: when computing vector element at index '1'
// :125:30: error: use of undefined value here causes illegal behavior
// :125:30: note: when computing vector element at index '0'
// :125:30: error: use of undefined value here causes illegal behavior
// :125:30: note: when computing vector element at index '0'
// :125:30: error: use of undefined value here causes illegal behavior
// :125:30: error: use of undefined value here causes illegal behavior
// :125:30: note: when computing vector element at index '0'
// :125:30: error: use of undefined value here causes illegal behavior
// :125:30: note: when computing vector element at index '0'
// :125:30: error: use of undefined value here causes illegal behavior
// :125:30: note: when computing vector element at index '1'
// :125:30: error: use of undefined value here causes illegal behavior
// :125:30: note: when computing vector element at index '0'
// :125:30: error: use of undefined value here causes illegal behavior
// :125:30: note: when computing vector element at index '0'
// :125:30: error: use of undefined value here causes illegal behavior
// :125:30: error: use of undefined value here causes illegal behavior
// :125:30: note: when computing vector element at index '0'
// :125:30: error: use of undefined value here causes illegal behavior
// :125:30: note: when computing vector element at index '0'
// :125:30: error: use of undefined value here causes illegal behavior
// :125:30: note: when computing vector element at index '1'
// :125:30: error: use of undefined value here causes illegal behavior
// :125:30: note: when computing vector element at index '0'
// :125:30: error: use of undefined value here causes illegal behavior
// :125:30: note: when computing vector element at index '0'
// :125:30: error: use of undefined value here causes illegal behavior
// :125:30: error: use of undefined value here causes illegal behavior
// :125:30: note: when computing vector element at index '0'
// :125:30: error: use of undefined value here causes illegal behavior
// :125:30: note: when computing vector element at index '0'
// :125:30: error: use of undefined value here causes illegal behavior
// :125:30: note: when computing vector element at index '1'
// :125:30: error: use of undefined value here causes illegal behavior
// :125:30: note: when computing vector element at index '0'
// :125:30: error: use of undefined value here causes illegal behavior
// :125:30: note: when computing vector element at index '0'
// :125:30: error: use of undefined value here causes illegal behavior
// :125:30: error: use of undefined value here causes illegal behavior
// :125:30: note: when computing vector element at index '0'
// :125:30: error: use of undefined value here causes illegal behavior
// :125:30: note: when computing vector element at index '0'
// :125:30: error: use of undefined value here causes illegal behavior
// :125:30: note: when computing vector element at index '1'
// :125:30: error: use of undefined value here causes illegal behavior
// :125:30: note: when computing vector element at index '0'
// :125:30: error: use of undefined value here causes illegal behavior
// :125:30: note: when computing vector element at index '0'
// :125:30: error: use of undefined value here causes illegal behavior
// :125:30: error: use of undefined value here causes illegal behavior
// :125:30: note: when computing vector element at index '0'
// :125:30: error: use of undefined value here causes illegal behavior
// :125:30: note: when computing vector element at index '0'
// :125:30: error: use of undefined value here causes illegal behavior
// :125:30: note: when computing vector element at index '1'
// :125:30: error: use of undefined value here causes illegal behavior
// :125:30: note: when computing vector element at index '0'
// :125:30: error: use of undefined value here causes illegal behavior
// :125:30: note: when computing vector element at index '0'
// :125:30: error: use of undefined value here causes illegal behavior
// :125:30: error: use of undefined value here causes illegal behavior
// :125:30: note: when computing vector element at index '0'
// :125:30: error: use of undefined value here causes illegal behavior
// :125:30: note: when computing vector element at index '0'
// :125:30: error: use of undefined value here causes illegal behavior
// :125:30: note: when computing vector element at index '1'
// :125:30: error: use of undefined value here causes illegal behavior
// :125:30: note: when computing vector element at index '0'
// :125:30: error: use of undefined value here causes illegal behavior
// :125:30: note: when computing vector element at index '0'
// :129:27: error: use of undefined value here causes illegal behavior
// :129:27: error: use of undefined value here causes illegal behavior
// :129:27: note: when computing vector element at index '0'
// :129:27: error: use of undefined value here causes illegal behavior
// :129:27: note: when computing vector element at index '0'
// :129:27: error: use of undefined value here causes illegal behavior
// :129:27: note: when computing vector element at index '0'
// :129:27: error: use of undefined value here causes illegal behavior
// :129:27: note: when computing vector element at index '1'
// :129:27: error: use of undefined value here causes illegal behavior
// :129:27: note: when computing vector element at index '0'
// :129:27: error: use of undefined value here causes illegal behavior
// :129:27: note: when computing vector element at index '0'
// :129:27: error: use of undefined value here causes illegal behavior
// :129:27: note: when computing vector element at index '0'
// :129:27: error: use of undefined value here causes illegal behavior
// :129:27: error: use of undefined value here causes illegal behavior
// :129:27: note: when computing vector element at index '0'
// :129:27: error: use of undefined value here causes illegal behavior
// :129:27: note: when computing vector element at index '0'
// :129:27: error: use of undefined value here causes illegal behavior
// :129:27: note: when computing vector element at index '0'
// :129:27: error: use of undefined value here causes illegal behavior
// :129:27: note: when computing vector element at index '1'
// :129:27: error: use of undefined value here causes illegal behavior
// :129:27: note: when computing vector element at index '0'
// :129:27: error: use of undefined value here causes illegal behavior
// :129:27: note: when computing vector element at index '0'
// :129:27: error: use of undefined value here causes illegal behavior
// :129:27: note: when computing vector element at index '0'
// :129:27: error: use of undefined value here causes illegal behavior
// :129:27: error: use of undefined value here causes illegal behavior
// :129:27: note: when computing vector element at index '0'
// :129:27: error: use of undefined value here causes illegal behavior
// :129:27: note: when computing vector element at index '0'
// :129:27: error: use of undefined value here causes illegal behavior
// :129:27: note: when computing vector element at index '0'
// :129:27: error: use of undefined value here causes illegal behavior
// :129:27: note: when computing vector element at index '1'
// :129:27: error: use of undefined value here causes illegal behavior
// :129:27: note: when computing vector element at index '0'
// :129:27: error: use of undefined value here causes illegal behavior
// :129:27: note: when computing vector element at index '0'
// :129:27: error: use of undefined value here causes illegal behavior
// :129:27: note: when computing vector element at index '0'
// :129:27: error: use of undefined value here causes illegal behavior
// :129:27: error: use of undefined value here causes illegal behavior
// :129:27: note: when computing vector element at index '0'
// :129:27: error: use of undefined value here causes illegal behavior
// :129:27: note: when computing vector element at index '0'
// :129:27: error: use of undefined value here causes illegal behavior
// :129:27: note: when computing vector element at index '0'
// :129:27: error: use of undefined value here causes illegal behavior
// :129:27: note: when computing vector element at index '1'
// :129:27: error: use of undefined value here causes illegal behavior
// :129:27: note: when computing vector element at index '0'
// :129:27: error: use of undefined value here causes illegal behavior
// :129:27: note: when computing vector element at index '0'
// :129:27: error: use of undefined value here causes illegal behavior
// :129:27: note: when computing vector element at index '0'
// :129:27: error: use of undefined value here causes illegal behavior
// :129:27: error: use of undefined value here causes illegal behavior
// :129:27: note: when computing vector element at index '0'
// :129:27: error: use of undefined value here causes illegal behavior
// :129:27: note: when computing vector element at index '0'
// :129:27: error: use of undefined value here causes illegal behavior
// :129:27: note: when computing vector element at index '0'
// :129:27: error: use of undefined value here causes illegal behavior
// :129:27: note: when computing vector element at index '1'
// :129:27: error: use of undefined value here causes illegal behavior
// :129:27: note: when computing vector element at index '0'
// :129:27: error: use of undefined value here causes illegal behavior
// :129:27: note: when computing vector element at index '0'
// :129:27: error: use of undefined value here causes illegal behavior
// :129:27: note: when computing vector element at index '0'
// :129:27: error: use of undefined value here causes illegal behavior
// :129:27: error: use of undefined value here causes illegal behavior
// :129:27: note: when computing vector element at index '0'
// :129:27: error: use of undefined value here causes illegal behavior
// :129:27: note: when computing vector element at index '0'
// :129:27: error: use of undefined value here causes illegal behavior
// :129:27: note: when computing vector element at index '0'
// :129:27: error: use of undefined value here causes illegal behavior
// :129:27: note: when computing vector element at index '1'
// :129:27: error: use of undefined value here causes illegal behavior
// :129:27: note: when computing vector element at index '0'
// :129:27: error: use of undefined value here causes illegal behavior
// :129:27: note: when computing vector element at index '0'
// :129:27: error: use of undefined value here causes illegal behavior
// :129:27: note: when computing vector element at index '0'
// :129:27: error: use of undefined value here causes illegal behavior
// :129:27: error: use of undefined value here causes illegal behavior
// :129:27: note: when computing vector element at index '0'
// :129:27: error: use of undefined value here causes illegal behavior
// :129:27: note: when computing vector element at index '0'
// :129:27: error: use of undefined value here causes illegal behavior
// :129:27: note: when computing vector element at index '0'
// :129:27: error: use of undefined value here causes illegal behavior
// :129:27: note: when computing vector element at index '1'
// :129:27: error: use of undefined value here causes illegal behavior
// :129:27: note: when computing vector element at index '0'
// :129:27: error: use of undefined value here causes illegal behavior
// :129:27: note: when computing vector element at index '0'
// :129:27: error: use of undefined value here causes illegal behavior
// :129:27: note: when computing vector element at index '0'
// :129:27: error: use of undefined value here causes illegal behavior
// :129:27: error: use of undefined value here causes illegal behavior
// :129:27: note: when computing vector element at index '0'
// :129:27: error: use of undefined value here causes illegal behavior
// :129:27: note: when computing vector element at index '0'
// :129:27: error: use of undefined value here causes illegal behavior
// :129:27: note: when computing vector element at index '0'
// :129:27: error: use of undefined value here causes illegal behavior
// :129:27: note: when computing vector element at index '1'
// :129:27: error: use of undefined value here causes illegal behavior
// :129:27: note: when computing vector element at index '0'
// :129:27: error: use of undefined value here causes illegal behavior
// :129:27: note: when computing vector element at index '0'
// :129:27: error: use of undefined value here causes illegal behavior
// :129:27: note: when computing vector element at index '0'
// :129:27: error: use of undefined value here causes illegal behavior
// :129:27: error: use of undefined value here causes illegal behavior
// :129:27: note: when computing vector element at index '0'
// :129:27: error: use of undefined value here causes illegal behavior
// :129:27: note: when computing vector element at index '0'
// :129:27: error: use of undefined value here causes illegal behavior
// :129:27: note: when computing vector element at index '0'
// :129:27: error: use of undefined value here causes illegal behavior
// :129:27: note: when computing vector element at index '1'
// :129:27: error: use of undefined value here causes illegal behavior
// :129:27: note: when computing vector element at index '0'
// :129:27: error: use of undefined value here causes illegal behavior
// :129:27: note: when computing vector element at index '0'
// :129:27: error: use of undefined value here causes illegal behavior
// :129:27: note: when computing vector element at index '0'
// :129:27: error: use of undefined value here causes illegal behavior
// :129:27: error: use of undefined value here causes illegal behavior
// :129:27: note: when computing vector element at index '0'
// :129:27: error: use of undefined value here causes illegal behavior
// :129:27: note: when computing vector element at index '0'
// :129:27: error: use of undefined value here causes illegal behavior
// :129:27: note: when computing vector element at index '0'
// :129:27: error: use of undefined value here causes illegal behavior
// :129:27: note: when computing vector element at index '1'
// :129:27: error: use of undefined value here causes illegal behavior
// :129:27: note: when computing vector element at index '0'
// :129:27: error: use of undefined value here causes illegal behavior
// :129:27: note: when computing vector element at index '0'
// :129:27: error: use of undefined value here causes illegal behavior
// :129:27: note: when computing vector element at index '0'
// :129:27: error: use of undefined value here causes illegal behavior
// :129:27: error: use of undefined value here causes illegal behavior
// :129:27: note: when computing vector element at index '0'
// :129:27: error: use of undefined value here causes illegal behavior
// :129:27: note: when computing vector element at index '0'
// :129:27: error: use of undefined value here causes illegal behavior
// :129:27: note: when computing vector element at index '0'
// :129:27: error: use of undefined value here causes illegal behavior
// :129:27: note: when computing vector element at index '1'
// :129:27: error: use of undefined value here causes illegal behavior
// :129:27: note: when computing vector element at index '0'
// :129:27: error: use of undefined value here causes illegal behavior
// :129:27: note: when computing vector element at index '0'
// :129:27: error: use of undefined value here causes illegal behavior
// :129:27: note: when computing vector element at index '0'
// :129:30: error: use of undefined value here causes illegal behavior
// :129:30: error: use of undefined value here causes illegal behavior
// :129:30: note: when computing vector element at index '0'
// :129:30: error: use of undefined value here causes illegal behavior
// :129:30: note: when computing vector element at index '0'
// :129:30: error: use of undefined value here causes illegal behavior
// :129:30: note: when computing vector element at index '1'
// :129:30: error: use of undefined value here causes illegal behavior
// :129:30: note: when computing vector element at index '0'
// :129:30: error: use of undefined value here causes illegal behavior
// :129:30: note: when computing vector element at index '0'
// :129:30: error: use of undefined value here causes illegal behavior
// :129:30: error: use of undefined value here causes illegal behavior
// :129:30: note: when computing vector element at index '0'
// :129:30: error: use of undefined value here causes illegal behavior
// :129:30: note: when computing vector element at index '0'
// :129:30: error: use of undefined value here causes illegal behavior
// :129:30: note: when computing vector element at index '1'
// :129:30: error: use of undefined value here causes illegal behavior
// :129:30: note: when computing vector element at index '0'
// :129:30: error: use of undefined value here causes illegal behavior
// :129:30: note: when computing vector element at index '0'
// :129:30: error: use of undefined value here causes illegal behavior
// :129:30: error: use of undefined value here causes illegal behavior
// :129:30: note: when computing vector element at index '0'
// :129:30: error: use of undefined value here causes illegal behavior
// :129:30: note: when computing vector element at index '0'
// :129:30: error: use of undefined value here causes illegal behavior
// :129:30: note: when computing vector element at index '1'
// :129:30: error: use of undefined value here causes illegal behavior
// :129:30: note: when computing vector element at index '0'
// :129:30: error: use of undefined value here causes illegal behavior
// :129:30: note: when computing vector element at index '0'
// :129:30: error: use of undefined value here causes illegal behavior
// :129:30: error: use of undefined value here causes illegal behavior
// :129:30: note: when computing vector element at index '0'
// :129:30: error: use of undefined value here causes illegal behavior
// :129:30: note: when computing vector element at index '0'
// :129:30: error: use of undefined value here causes illegal behavior
// :129:30: note: when computing vector element at index '1'
// :129:30: error: use of undefined value here causes illegal behavior
// :129:30: note: when computing vector element at index '0'
// :129:30: error: use of undefined value here causes illegal behavior
// :129:30: note: when computing vector element at index '0'
// :129:30: error: use of undefined value here causes illegal behavior
// :129:30: error: use of undefined value here causes illegal behavior
// :129:30: note: when computing vector element at index '0'
// :129:30: error: use of undefined value here causes illegal behavior
// :129:30: note: when computing vector element at index '0'
// :129:30: error: use of undefined value here causes illegal behavior
// :129:30: note: when computing vector element at index '1'
// :129:30: error: use of undefined value here causes illegal behavior
// :129:30: note: when computing vector element at index '0'
// :129:30: error: use of undefined value here causes illegal behavior
// :129:30: note: when computing vector element at index '0'
// :129:30: error: use of undefined value here causes illegal behavior
// :129:30: error: use of undefined value here causes illegal behavior
// :129:30: note: when computing vector element at index '0'
// :129:30: error: use of undefined value here causes illegal behavior
// :129:30: note: when computing vector element at index '0'
// :129:30: error: use of undefined value here causes illegal behavior
// :129:30: note: when computing vector element at index '1'
// :129:30: error: use of undefined value here causes illegal behavior
// :129:30: note: when computing vector element at index '0'
// :129:30: error: use of undefined value here causes illegal behavior
// :129:30: note: when computing vector element at index '0'
// :129:30: error: use of undefined value here causes illegal behavior
// :129:30: error: use of undefined value here causes illegal behavior
// :129:30: note: when computing vector element at index '0'
// :129:30: error: use of undefined value here causes illegal behavior
// :129:30: note: when computing vector element at index '0'
// :129:30: error: use of undefined value here causes illegal behavior
// :129:30: note: when computing vector element at index '1'
// :129:30: error: use of undefined value here causes illegal behavior
// :129:30: note: when computing vector element at index '0'
// :129:30: error: use of undefined value here causes illegal behavior
// :129:30: note: when computing vector element at index '0'
// :129:30: error: use of undefined value here causes illegal behavior
// :129:30: error: use of undefined value here causes illegal behavior
// :129:30: note: when computing vector element at index '0'
// :129:30: error: use of undefined value here causes illegal behavior
// :129:30: note: when computing vector element at index '0'
// :129:30: error: use of undefined value here causes illegal behavior
// :129:30: note: when computing vector element at index '1'
// :129:30: error: use of undefined value here causes illegal behavior
// :129:30: note: when computing vector element at index '0'
// :129:30: error: use of undefined value here causes illegal behavior
// :129:30: note: when computing vector element at index '0'
// :129:30: error: use of undefined value here causes illegal behavior
// :129:30: error: use of undefined value here causes illegal behavior
// :129:30: note: when computing vector element at index '0'
// :129:30: error: use of undefined value here causes illegal behavior
// :129:30: note: when computing vector element at index '0'
// :129:30: error: use of undefined value here causes illegal behavior
// :129:30: note: when computing vector element at index '1'
// :129:30: error: use of undefined value here causes illegal behavior
// :129:30: note: when computing vector element at index '0'
// :129:30: error: use of undefined value here causes illegal behavior
// :129:30: note: when computing vector element at index '0'
// :129:30: error: use of undefined value here causes illegal behavior
// :129:30: error: use of undefined value here causes illegal behavior
// :129:30: note: when computing vector element at index '0'
// :129:30: error: use of undefined value here causes illegal behavior
// :129:30: note: when computing vector element at index '0'
// :129:30: error: use of undefined value here causes illegal behavior
// :129:30: note: when computing vector element at index '1'
// :129:30: error: use of undefined value here causes illegal behavior
// :129:30: note: when computing vector element at index '0'
// :129:30: error: use of undefined value here causes illegal behavior
// :129:30: note: when computing vector element at index '0'
// :129:30: error: use of undefined value here causes illegal behavior
// :129:30: error: use of undefined value here causes illegal behavior
// :129:30: note: when computing vector element at index '0'
// :129:30: error: use of undefined value here causes illegal behavior
// :129:30: note: when computing vector element at index '0'
// :129:30: error: use of undefined value here causes illegal behavior
// :129:30: note: when computing vector element at index '1'
// :129:30: error: use of undefined value here causes illegal behavior
// :129:30: note: when computing vector element at index '0'
// :129:30: error: use of undefined value here causes illegal behavior
// :129:30: note: when computing vector element at index '0'
// :133:27: error: use of undefined value here causes illegal behavior
// :133:27: error: use of undefined value here causes illegal behavior
// :133:27: note: when computing vector element at index '0'
// :133:27: error: use of undefined value here causes illegal behavior
// :133:27: note: when computing vector element at index '0'
// :133:27: error: use of undefined value here causes illegal behavior
// :133:27: note: when computing vector element at index '0'
// :133:27: error: use of undefined value here causes illegal behavior
// :133:27: note: when computing vector element at index '1'
// :133:27: error: use of undefined value here causes illegal behavior
// :133:27: note: when computing vector element at index '0'
// :133:27: error: use of undefined value here causes illegal behavior
// :133:27: note: when computing vector element at index '0'
// :133:27: error: use of undefined value here causes illegal behavior
// :133:27: note: when computing vector element at index '0'
// :133:27: error: use of undefined value here causes illegal behavior
// :133:27: error: use of undefined value here causes illegal behavior
// :133:27: note: when computing vector element at index '0'
// :133:27: error: use of undefined value here causes illegal behavior
// :133:27: note: when computing vector element at index '0'
// :133:27: error: use of undefined value here causes illegal behavior
// :133:27: note: when computing vector element at index '0'
// :133:27: error: use of undefined value here causes illegal behavior
// :133:27: note: when computing vector element at index '1'
// :133:27: error: use of undefined value here causes illegal behavior
// :133:27: note: when computing vector element at index '0'
// :133:27: error: use of undefined value here causes illegal behavior
// :133:27: note: when computing vector element at index '0'
// :133:27: error: use of undefined value here causes illegal behavior
// :133:27: note: when computing vector element at index '0'
// :133:27: error: use of undefined value here causes illegal behavior
// :133:27: error: use of undefined value here causes illegal behavior
// :133:27: note: when computing vector element at index '0'
// :133:27: error: use of undefined value here causes illegal behavior
// :133:27: note: when computing vector element at index '0'
// :133:27: error: use of undefined value here causes illegal behavior
// :133:27: note: when computing vector element at index '0'
// :133:27: error: use of undefined value here causes illegal behavior
// :133:27: note: when computing vector element at index '1'
// :133:27: error: use of undefined value here causes illegal behavior
// :133:27: note: when computing vector element at index '0'
// :133:27: error: use of undefined value here causes illegal behavior
// :133:27: note: when computing vector element at index '0'
// :133:27: error: use of undefined value here causes illegal behavior
// :133:27: note: when computing vector element at index '0'
// :133:27: error: use of undefined value here causes illegal behavior
// :133:27: error: use of undefined value here causes illegal behavior
// :133:27: note: when computing vector element at index '0'
// :133:27: error: use of undefined value here causes illegal behavior
// :133:27: note: when computing vector element at index '0'
// :133:27: error: use of undefined value here causes illegal behavior
// :133:27: note: when computing vector element at index '0'
// :133:27: error: use of undefined value here causes illegal behavior
// :133:27: note: when computing vector element at index '1'
// :133:27: error: use of undefined value here causes illegal behavior
// :133:27: note: when computing vector element at index '0'
// :133:27: error: use of undefined value here causes illegal behavior
// :133:27: note: when computing vector element at index '0'
// :133:27: error: use of undefined value here causes illegal behavior
// :133:27: note: when computing vector element at index '0'
// :133:27: error: use of undefined value here causes illegal behavior
// :133:27: error: use of undefined value here causes illegal behavior
// :133:27: note: when computing vector element at index '0'
// :133:27: error: use of undefined value here causes illegal behavior
// :133:27: note: when computing vector element at index '0'
// :133:27: error: use of undefined value here causes illegal behavior
// :133:27: note: when computing vector element at index '0'
// :133:27: error: use of undefined value here causes illegal behavior
// :133:27: note: when computing vector element at index '1'
// :133:27: error: use of undefined value here causes illegal behavior
// :133:27: note: when computing vector element at index '0'
// :133:27: error: use of undefined value here causes illegal behavior
// :133:27: note: when computing vector element at index '0'
// :133:27: error: use of undefined value here causes illegal behavior
// :133:27: note: when computing vector element at index '0'
// :133:27: error: use of undefined value here causes illegal behavior
// :133:27: error: use of undefined value here causes illegal behavior
// :133:27: note: when computing vector element at index '0'
// :133:27: error: use of undefined value here causes illegal behavior
// :133:27: note: when computing vector element at index '0'
// :133:27: error: use of undefined value here causes illegal behavior
// :133:27: note: when computing vector element at index '0'
// :133:27: error: use of undefined value here causes illegal behavior
// :133:27: note: when computing vector element at index '1'
// :133:27: error: use of undefined value here causes illegal behavior
// :133:27: note: when computing vector element at index '0'
// :133:27: error: use of undefined value here causes illegal behavior
// :133:27: note: when computing vector element at index '0'
// :133:27: error: use of undefined value here causes illegal behavior
// :133:27: note: when computing vector element at index '0'
// :133:27: error: use of undefined value here causes illegal behavior
// :133:27: error: use of undefined value here causes illegal behavior
// :133:27: note: when computing vector element at index '0'
// :133:27: error: use of undefined value here causes illegal behavior
// :133:27: note: when computing vector element at index '0'
// :133:27: error: use of undefined value here causes illegal behavior
// :133:27: note: when computing vector element at index '0'
// :133:27: error: use of undefined value here causes illegal behavior
// :133:27: note: when computing vector element at index '1'
// :133:27: error: use of undefined value here causes illegal behavior
// :133:27: note: when computing vector element at index '0'
// :133:27: error: use of undefined value here causes illegal behavior
// :133:27: note: when computing vector element at index '0'
// :133:27: error: use of undefined value here causes illegal behavior
// :133:27: note: when computing vector element at index '0'
// :133:27: error: use of undefined value here causes illegal behavior
// :133:27: error: use of undefined value here causes illegal behavior
// :133:27: note: when computing vector element at index '0'
// :133:27: error: use of undefined value here causes illegal behavior
// :133:27: note: when computing vector element at index '0'
// :133:27: error: use of undefined value here causes illegal behavior
// :133:27: note: when computing vector element at index '0'
// :133:27: error: use of undefined value here causes illegal behavior
// :133:27: note: when computing vector element at index '1'
// :133:27: error: use of undefined value here causes illegal behavior
// :133:27: note: when computing vector element at index '0'
// :133:27: error: use of undefined value here causes illegal behavior
// :133:27: note: when computing vector element at index '0'
// :133:27: error: use of undefined value here causes illegal behavior
// :133:27: note: when computing vector element at index '0'
// :133:27: error: use of undefined value here causes illegal behavior
// :133:27: error: use of undefined value here causes illegal behavior
// :133:27: note: when computing vector element at index '0'
// :133:27: error: use of undefined value here causes illegal behavior
// :133:27: note: when computing vector element at index '0'
// :133:27: error: use of undefined value here causes illegal behavior
// :133:27: note: when computing vector element at index '0'
// :133:27: error: use of undefined value here causes illegal behavior
// :133:27: note: when computing vector element at index '1'
// :133:27: error: use of undefined value here causes illegal behavior
// :133:27: note: when computing vector element at index '0'
// :133:27: error: use of undefined value here causes illegal behavior
// :133:27: note: when computing vector element at index '0'
// :133:27: error: use of undefined value here causes illegal behavior
// :133:27: note: when computing vector element at index '0'
// :133:27: error: use of undefined value here causes illegal behavior
// :133:27: error: use of undefined value here causes illegal behavior
// :133:27: note: when computing vector element at index '0'
// :133:27: error: use of undefined value here causes illegal behavior
// :133:27: note: when computing vector element at index '0'
// :133:27: error: use of undefined value here causes illegal behavior
// :133:27: note: when computing vector element at index '0'
// :133:27: error: use of undefined value here causes illegal behavior
// :133:27: note: when computing vector element at index '1'
// :133:27: error: use of undefined value here causes illegal behavior
// :133:27: note: when computing vector element at index '0'
// :133:27: error: use of undefined value here causes illegal behavior
// :133:27: note: when computing vector element at index '0'
// :133:27: error: use of undefined value here causes illegal behavior
// :133:27: note: when computing vector element at index '0'
// :133:27: error: use of undefined value here causes illegal behavior
// :133:27: error: use of undefined value here causes illegal behavior
// :133:27: note: when computing vector element at index '0'
// :133:27: error: use of undefined value here causes illegal behavior
// :133:27: note: when computing vector element at index '0'
// :133:27: error: use of undefined value here causes illegal behavior
// :133:27: note: when computing vector element at index '0'
// :133:27: error: use of undefined value here causes illegal behavior
// :133:27: note: when computing vector element at index '1'
// :133:27: error: use of undefined value here causes illegal behavior
// :133:27: note: when computing vector element at index '0'
// :133:27: error: use of undefined value here causes illegal behavior
// :133:27: note: when computing vector element at index '0'
// :133:27: error: use of undefined value here causes illegal behavior
// :133:27: note: when computing vector element at index '0'
// :133:30: error: use of undefined value here causes illegal behavior
// :133:30: error: use of undefined value here causes illegal behavior
// :133:30: note: when computing vector element at index '0'
// :133:30: error: use of undefined value here causes illegal behavior
// :133:30: note: when computing vector element at index '0'
// :133:30: error: use of undefined value here causes illegal behavior
// :133:30: note: when computing vector element at index '1'
// :133:30: error: use of undefined value here causes illegal behavior
// :133:30: note: when computing vector element at index '0'
// :133:30: error: use of undefined value here causes illegal behavior
// :133:30: note: when computing vector element at index '0'
// :133:30: error: use of undefined value here causes illegal behavior
// :133:30: error: use of undefined value here causes illegal behavior
// :133:30: note: when computing vector element at index '0'
// :133:30: error: use of undefined value here causes illegal behavior
// :133:30: note: when computing vector element at index '0'
// :133:30: error: use of undefined value here causes illegal behavior
// :133:30: note: when computing vector element at index '1'
// :133:30: error: use of undefined value here causes illegal behavior
// :133:30: note: when computing vector element at index '0'
// :133:30: error: use of undefined value here causes illegal behavior
// :133:30: note: when computing vector element at index '0'
// :133:30: error: use of undefined value here causes illegal behavior
// :133:30: error: use of undefined value here causes illegal behavior
// :133:30: note: when computing vector element at index '0'
// :133:30: error: use of undefined value here causes illegal behavior
// :133:30: note: when computing vector element at index '0'
// :133:30: error: use of undefined value here causes illegal behavior
// :133:30: note: when computing vector element at index '1'
// :133:30: error: use of undefined value here causes illegal behavior
// :133:30: note: when computing vector element at index '0'
// :133:30: error: use of undefined value here causes illegal behavior
// :133:30: note: when computing vector element at index '0'
// :133:30: error: use of undefined value here causes illegal behavior
// :133:30: error: use of undefined value here causes illegal behavior
// :133:30: note: when computing vector element at index '0'
// :133:30: error: use of undefined value here causes illegal behavior
// :133:30: note: when computing vector element at index '0'
// :133:30: error: use of undefined value here causes illegal behavior
// :133:30: note: when computing vector element at index '1'
// :133:30: error: use of undefined value here causes illegal behavior
// :133:30: note: when computing vector element at index '0'
// :133:30: error: use of undefined value here causes illegal behavior
// :133:30: note: when computing vector element at index '0'
// :133:30: error: use of undefined value here causes illegal behavior
// :133:30: error: use of undefined value here causes illegal behavior
// :133:30: note: when computing vector element at index '0'
// :133:30: error: use of undefined value here causes illegal behavior
// :133:30: note: when computing vector element at index '0'
// :133:30: error: use of undefined value here causes illegal behavior
// :133:30: note: when computing vector element at index '1'
// :133:30: error: use of undefined value here causes illegal behavior
// :133:30: note: when computing vector element at index '0'
// :133:30: error: use of undefined value here causes illegal behavior
// :133:30: note: when computing vector element at index '0'
// :133:30: error: use of undefined value here causes illegal behavior
// :133:30: error: use of undefined value here causes illegal behavior
// :133:30: note: when computing vector element at index '0'
// :133:30: error: use of undefined value here causes illegal behavior
// :133:30: note: when computing vector element at index '0'
// :133:30: error: use of undefined value here causes illegal behavior
// :133:30: note: when computing vector element at index '1'
// :133:30: error: use of undefined value here causes illegal behavior
// :133:30: note: when computing vector element at index '0'
// :133:30: error: use of undefined value here causes illegal behavior
// :133:30: note: when computing vector element at index '0'
// :133:30: error: use of undefined value here causes illegal behavior
// :133:30: error: use of undefined value here causes illegal behavior
// :133:30: note: when computing vector element at index '0'
// :133:30: error: use of undefined value here causes illegal behavior
// :133:30: note: when computing vector element at index '0'
// :133:30: error: use of undefined value here causes illegal behavior
// :133:30: note: when computing vector element at index '1'
// :133:30: error: use of undefined value here causes illegal behavior
// :133:30: note: when computing vector element at index '0'
// :133:30: error: use of undefined value here causes illegal behavior
// :133:30: note: when computing vector element at index '0'
// :133:30: error: use of undefined value here causes illegal behavior
// :133:30: error: use of undefined value here causes illegal behavior
// :133:30: note: when computing vector element at index '0'
// :133:30: error: use of undefined value here causes illegal behavior
// :133:30: note: when computing vector element at index '0'
// :133:30: error: use of undefined value here causes illegal behavior
// :133:30: note: when computing vector element at index '1'
// :133:30: error: use of undefined value here causes illegal behavior
// :133:30: note: when computing vector element at index '0'
// :133:30: error: use of undefined value here causes illegal behavior
// :133:30: note: when computing vector element at index '0'
// :133:30: error: use of undefined value here causes illegal behavior
// :133:30: error: use of undefined value here causes illegal behavior
// :133:30: note: when computing vector element at index '0'
// :133:30: error: use of undefined value here causes illegal behavior
// :133:30: note: when computing vector element at index '0'
// :133:30: error: use of undefined value here causes illegal behavior
// :133:30: note: when computing vector element at index '1'
// :133:30: error: use of undefined value here causes illegal behavior
// :133:30: note: when computing vector element at index '0'
// :133:30: error: use of undefined value here causes illegal behavior
// :133:30: note: when computing vector element at index '0'
// :133:30: error: use of undefined value here causes illegal behavior
// :133:30: error: use of undefined value here causes illegal behavior
// :133:30: note: when computing vector element at index '0'
// :133:30: error: use of undefined value here causes illegal behavior
// :133:30: note: when computing vector element at index '0'
// :133:30: error: use of undefined value here causes illegal behavior
// :133:30: note: when computing vector element at index '1'
// :133:30: error: use of undefined value here causes illegal behavior
// :133:30: note: when computing vector element at index '0'
// :133:30: error: use of undefined value here causes illegal behavior
// :133:30: note: when computing vector element at index '0'
// :133:30: error: use of undefined value here causes illegal behavior
// :133:30: error: use of undefined value here causes illegal behavior
// :133:30: note: when computing vector element at index '0'
// :133:30: error: use of undefined value here causes illegal behavior
// :133:30: note: when computing vector element at index '0'
// :133:30: error: use of undefined value here causes illegal behavior
// :133:30: note: when computing vector element at index '1'
// :133:30: error: use of undefined value here causes illegal behavior
// :133:30: note: when computing vector element at index '0'
// :133:30: error: use of undefined value here causes illegal behavior
// :133:30: note: when computing vector element at index '0'
// :137:17: error: use of undefined value here causes illegal behavior
// :137:17: error: use of undefined value here causes illegal behavior
// :137:17: note: when computing vector element at index '0'
// :137:17: error: use of undefined value here causes illegal behavior
// :137:17: note: when computing vector element at index '0'
// :137:17: error: use of undefined value here causes illegal behavior
// :137:17: note: when computing vector element at index '0'
// :137:17: error: use of undefined value here causes illegal behavior
// :137:17: note: when computing vector element at index '1'
// :137:17: error: use of undefined value here causes illegal behavior
// :137:17: note: when computing vector element at index '0'
// :137:17: error: use of undefined value here causes illegal behavior
// :137:17: note: when computing vector element at index '0'
// :137:17: error: use of undefined value here causes illegal behavior
// :137:17: note: when computing vector element at index '0'
// :137:17: error: use of undefined value here causes illegal behavior
// :137:17: error: use of undefined value here causes illegal behavior
// :137:17: note: when computing vector element at index '0'
// :137:17: error: use of undefined value here causes illegal behavior
// :137:17: note: when computing vector element at index '0'
// :137:17: error: use of undefined value here causes illegal behavior
// :137:17: note: when computing vector element at index '0'
// :137:17: error: use of undefined value here causes illegal behavior
// :137:17: note: when computing vector element at index '1'
// :137:17: error: use of undefined value here causes illegal behavior
// :137:17: note: when computing vector element at index '0'
// :137:17: error: use of undefined value here causes illegal behavior
// :137:17: note: when computing vector element at index '0'
// :137:17: error: use of undefined value here causes illegal behavior
// :137:17: note: when computing vector element at index '0'
// :137:17: error: use of undefined value here causes illegal behavior
// :137:17: error: use of undefined value here causes illegal behavior
// :137:17: note: when computing vector element at index '0'
// :137:17: error: use of undefined value here causes illegal behavior
// :137:17: note: when computing vector element at index '0'
// :137:17: error: use of undefined value here causes illegal behavior
// :137:17: note: when computing vector element at index '0'
// :137:17: error: use of undefined value here causes illegal behavior
// :137:17: note: when computing vector element at index '1'
// :137:17: error: use of undefined value here causes illegal behavior
// :137:17: note: when computing vector element at index '0'
// :137:17: error: use of undefined value here causes illegal behavior
// :137:17: note: when computing vector element at index '0'
// :137:17: error: use of undefined value here causes illegal behavior
// :137:17: note: when computing vector element at index '0'
// :137:17: error: use of undefined value here causes illegal behavior
// :137:17: error: use of undefined value here causes illegal behavior
// :137:17: note: when computing vector element at index '0'
// :137:17: error: use of undefined value here causes illegal behavior
// :137:17: note: when computing vector element at index '0'
// :137:17: error: use of undefined value here causes illegal behavior
// :137:17: note: when computing vector element at index '0'
// :137:17: error: use of undefined value here causes illegal behavior
// :137:17: note: when computing vector element at index '1'
// :137:17: error: use of undefined value here causes illegal behavior
// :137:17: note: when computing vector element at index '0'
// :137:17: error: use of undefined value here causes illegal behavior
// :137:17: note: when computing vector element at index '0'
// :137:17: error: use of undefined value here causes illegal behavior
// :137:17: note: when computing vector element at index '0'
// :137:17: error: use of undefined value here causes illegal behavior
// :137:17: error: use of undefined value here causes illegal behavior
// :137:17: note: when computing vector element at index '0'
// :137:17: error: use of undefined value here causes illegal behavior
// :137:17: note: when computing vector element at index '0'
// :137:17: error: use of undefined value here causes illegal behavior
// :137:17: note: when computing vector element at index '0'
// :137:17: error: use of undefined value here causes illegal behavior
// :137:17: note: when computing vector element at index '1'
// :137:17: error: use of undefined value here causes illegal behavior
// :137:17: note: when computing vector element at index '0'
// :137:17: error: use of undefined value here causes illegal behavior
// :137:17: note: when computing vector element at index '0'
// :137:17: error: use of undefined value here causes illegal behavior
// :137:17: note: when computing vector element at index '0'
// :137:17: error: use of undefined value here causes illegal behavior
// :137:17: error: use of undefined value here causes illegal behavior
// :137:17: note: when computing vector element at index '0'
// :137:17: error: use of undefined value here causes illegal behavior
// :137:17: note: when computing vector element at index '0'
// :137:17: error: use of undefined value here causes illegal behavior
// :137:17: note: when computing vector element at index '0'
// :137:17: error: use of undefined value here causes illegal behavior
// :137:17: note: when computing vector element at index '1'
// :137:17: error: use of undefined value here causes illegal behavior
// :137:17: note: when computing vector element at index '0'
// :137:17: error: use of undefined value here causes illegal behavior
// :137:17: note: when computing vector element at index '0'
// :137:17: error: use of undefined value here causes illegal behavior
// :137:17: note: when computing vector element at index '0'
// :137:17: error: use of undefined value here causes illegal behavior
// :137:17: error: use of undefined value here causes illegal behavior
// :137:17: note: when computing vector element at index '0'
// :137:17: error: use of undefined value here causes illegal behavior
// :137:17: note: when computing vector element at index '0'
// :137:17: error: use of undefined value here causes illegal behavior
// :137:17: note: when computing vector element at index '0'
// :137:17: error: use of undefined value here causes illegal behavior
// :137:17: note: when computing vector element at index '1'
// :137:17: error: use of undefined value here causes illegal behavior
// :137:17: note: when computing vector element at index '0'
// :137:17: error: use of undefined value here causes illegal behavior
// :137:17: note: when computing vector element at index '0'
// :137:17: error: use of undefined value here causes illegal behavior
// :137:17: note: when computing vector element at index '0'
// :137:17: error: use of undefined value here causes illegal behavior
// :137:17: error: use of undefined value here causes illegal behavior
// :137:17: note: when computing vector element at index '0'
// :137:17: error: use of undefined value here causes illegal behavior
// :137:17: note: when computing vector element at index '0'
// :137:17: error: use of undefined value here causes illegal behavior
// :137:17: note: when computing vector element at index '0'
// :137:17: error: use of undefined value here causes illegal behavior
// :137:17: note: when computing vector element at index '1'
// :137:17: error: use of undefined value here causes illegal behavior
// :137:17: note: when computing vector element at index '0'
// :137:17: error: use of undefined value here causes illegal behavior
// :137:17: note: when computing vector element at index '0'
// :137:17: error: use of undefined value here causes illegal behavior
// :137:17: note: when computing vector element at index '0'
// :137:17: error: use of undefined value here causes illegal behavior
// :137:17: error: use of undefined value here causes illegal behavior
// :137:17: note: when computing vector element at index '0'
// :137:17: error: use of undefined value here causes illegal behavior
// :137:17: note: when computing vector element at index '0'
// :137:17: error: use of undefined value here causes illegal behavior
// :137:17: note: when computing vector element at index '0'
// :137:17: error: use of undefined value here causes illegal behavior
// :137:17: note: when computing vector element at index '1'
// :137:17: error: use of undefined value here causes illegal behavior
// :137:17: note: when computing vector element at index '0'
// :137:17: error: use of undefined value here causes illegal behavior
// :137:17: note: when computing vector element at index '0'
// :137:17: error: use of undefined value here causes illegal behavior
// :137:17: note: when computing vector element at index '0'
// :137:17: error: use of undefined value here causes illegal behavior
// :137:17: error: use of undefined value here causes illegal behavior
// :137:17: note: when computing vector element at index '0'
// :137:17: error: use of undefined value here causes illegal behavior
// :137:17: note: when computing vector element at index '0'
// :137:17: error: use of undefined value here causes illegal behavior
// :137:17: note: when computing vector element at index '0'
// :137:17: error: use of undefined value here causes illegal behavior
// :137:17: note: when computing vector element at index '1'
// :137:17: error: use of undefined value here causes illegal behavior
// :137:17: note: when computing vector element at index '0'
// :137:17: error: use of undefined value here causes illegal behavior
// :137:17: note: when computing vector element at index '0'
// :137:17: error: use of undefined value here causes illegal behavior
// :137:17: note: when computing vector element at index '0'
// :137:17: error: use of undefined value here causes illegal behavior
// :137:17: error: use of undefined value here causes illegal behavior
// :137:17: note: when computing vector element at index '0'
// :137:17: error: use of undefined value here causes illegal behavior
// :137:17: note: when computing vector element at index '0'
// :137:17: error: use of undefined value here causes illegal behavior
// :137:17: note: when computing vector element at index '0'
// :137:17: error: use of undefined value here causes illegal behavior
// :137:17: note: when computing vector element at index '1'
// :137:17: error: use of undefined value here causes illegal behavior
// :137:17: note: when computing vector element at index '0'
// :137:17: error: use of undefined value here causes illegal behavior
// :137:17: note: when computing vector element at index '0'
// :137:17: error: use of undefined value here causes illegal behavior
// :137:17: note: when computing vector element at index '0'
// :137:21: error: use of undefined value here causes illegal behavior
// :137:21: error: use of undefined value here causes illegal behavior
// :137:21: note: when computing vector element at index '0'
// :137:21: error: use of undefined value here causes illegal behavior
// :137:21: note: when computing vector element at index '0'
// :137:21: error: use of undefined value here causes illegal behavior
// :137:21: note: when computing vector element at index '1'
// :137:21: error: use of undefined value here causes illegal behavior
// :137:21: note: when computing vector element at index '0'
// :137:21: error: use of undefined value here causes illegal behavior
// :137:21: note: when computing vector element at index '0'
// :137:21: error: use of undefined value here causes illegal behavior
// :137:21: error: use of undefined value here causes illegal behavior
// :137:21: note: when computing vector element at index '0'
// :137:21: error: use of undefined value here causes illegal behavior
// :137:21: note: when computing vector element at index '0'
// :137:21: error: use of undefined value here causes illegal behavior
// :137:21: note: when computing vector element at index '1'
// :137:21: error: use of undefined value here causes illegal behavior
// :137:21: note: when computing vector element at index '0'
// :137:21: error: use of undefined value here causes illegal behavior
// :137:21: note: when computing vector element at index '0'
// :137:21: error: use of undefined value here causes illegal behavior
// :137:21: error: use of undefined value here causes illegal behavior
// :137:21: note: when computing vector element at index '0'
// :137:21: error: use of undefined value here causes illegal behavior
// :137:21: note: when computing vector element at index '0'
// :137:21: error: use of undefined value here causes illegal behavior
// :137:21: note: when computing vector element at index '1'
// :137:21: error: use of undefined value here causes illegal behavior
// :137:21: note: when computing vector element at index '0'
// :137:21: error: use of undefined value here causes illegal behavior
// :137:21: note: when computing vector element at index '0'
// :137:21: error: use of undefined value here causes illegal behavior
// :137:21: error: use of undefined value here causes illegal behavior
// :137:21: note: when computing vector element at index '0'
// :137:21: error: use of undefined value here causes illegal behavior
// :137:21: note: when computing vector element at index '0'
// :137:21: error: use of undefined value here causes illegal behavior
// :137:21: note: when computing vector element at index '1'
// :137:21: error: use of undefined value here causes illegal behavior
// :137:21: note: when computing vector element at index '0'
// :137:21: error: use of undefined value here causes illegal behavior
// :137:21: note: when computing vector element at index '0'
// :137:21: error: use of undefined value here causes illegal behavior
// :137:21: error: use of undefined value here causes illegal behavior
// :137:21: note: when computing vector element at index '0'
// :137:21: error: use of undefined value here causes illegal behavior
// :137:21: note: when computing vector element at index '0'
// :137:21: error: use of undefined value here causes illegal behavior
// :137:21: note: when computing vector element at index '1'
// :137:21: error: use of undefined value here causes illegal behavior
// :137:21: note: when computing vector element at index '0'
// :137:21: error: use of undefined value here causes illegal behavior
// :137:21: note: when computing vector element at index '0'
// :137:21: error: use of undefined value here causes illegal behavior
// :137:21: error: use of undefined value here causes illegal behavior
// :137:21: note: when computing vector element at index '0'
// :137:21: error: use of undefined value here causes illegal behavior
// :137:21: note: when computing vector element at index '0'
// :137:21: error: use of undefined value here causes illegal behavior
// :137:21: note: when computing vector element at index '1'
// :137:21: error: use of undefined value here causes illegal behavior
// :137:21: note: when computing vector element at index '0'
// :137:21: error: use of undefined value here causes illegal behavior
// :137:21: note: when computing vector element at index '0'
// :137:21: error: use of undefined value here causes illegal behavior
// :137:21: error: use of undefined value here causes illegal behavior
// :137:21: note: when computing vector element at index '0'
// :137:21: error: use of undefined value here causes illegal behavior
// :137:21: note: when computing vector element at index '0'
// :137:21: error: use of undefined value here causes illegal behavior
// :137:21: note: when computing vector element at index '1'
// :137:21: error: use of undefined value here causes illegal behavior
// :137:21: note: when computing vector element at index '0'
// :137:21: error: use of undefined value here causes illegal behavior
// :137:21: note: when computing vector element at index '0'
// :137:21: error: use of undefined value here causes illegal behavior
// :137:21: error: use of undefined value here causes illegal behavior
// :137:21: note: when computing vector element at index '0'
// :137:21: error: use of undefined value here causes illegal behavior
// :137:21: note: when computing vector element at index '0'
// :137:21: error: use of undefined value here causes illegal behavior
// :137:21: note: when computing vector element at index '1'
// :137:21: error: use of undefined value here causes illegal behavior
// :137:21: note: when computing vector element at index '0'
// :137:21: error: use of undefined value here causes illegal behavior
// :137:21: note: when computing vector element at index '0'
// :137:21: error: use of undefined value here causes illegal behavior
// :137:21: error: use of undefined value here causes illegal behavior
// :137:21: note: when computing vector element at index '0'
// :137:21: error: use of undefined value here causes illegal behavior
// :137:21: note: when computing vector element at index '0'
// :137:21: error: use of undefined value here causes illegal behavior
// :137:21: note: when computing vector element at index '1'
// :137:21: error: use of undefined value here causes illegal behavior
// :137:21: note: when computing vector element at index '0'
// :137:21: error: use of undefined value here causes illegal behavior
// :137:21: note: when computing vector element at index '0'
// :137:21: error: use of undefined value here causes illegal behavior
// :137:21: error: use of undefined value here causes illegal behavior
// :137:21: note: when computing vector element at index '0'
// :137:21: error: use of undefined value here causes illegal behavior
// :137:21: note: when computing vector element at index '0'
// :137:21: error: use of undefined value here causes illegal behavior
// :137:21: note: when computing vector element at index '1'
// :137:21: error: use of undefined value here causes illegal behavior
// :137:21: note: when computing vector element at index '0'
// :137:21: error: use of undefined value here causes illegal behavior
// :137:21: note: when computing vector element at index '0'
// :137:21: error: use of undefined value here causes illegal behavior
// :137:21: error: use of undefined value here causes illegal behavior
// :137:21: note: when computing vector element at index '0'
// :137:21: error: use of undefined value here causes illegal behavior
// :137:21: note: when computing vector element at index '0'
// :137:21: error: use of undefined value here causes illegal behavior
// :137:21: note: when computing vector element at index '1'
// :137:21: error: use of undefined value here causes illegal behavior
// :137:21: note: when computing vector element at index '0'
// :137:21: error: use of undefined value here causes illegal behavior
// :137:21: note: when computing vector element at index '0'
// :141:22: error: use of undefined value here causes illegal behavior
// :141:22: error: use of undefined value here causes illegal behavior
// :141:22: note: when computing vector element at index '0'
// :141:22: error: use of undefined value here causes illegal behavior
// :141:22: note: when computing vector element at index '0'
// :141:22: error: use of undefined value here causes illegal behavior
// :141:22: note: when computing vector element at index '0'
// :141:22: error: use of undefined value here causes illegal behavior
// :141:22: note: when computing vector element at index '1'
// :141:22: error: use of undefined value here causes illegal behavior
// :141:22: note: when computing vector element at index '0'
// :141:22: error: use of undefined value here causes illegal behavior
// :141:22: note: when computing vector element at index '0'
// :141:22: error: use of undefined value here causes illegal behavior
// :141:22: note: when computing vector element at index '0'
// :141:22: error: use of undefined value here causes illegal behavior
// :141:22: error: use of undefined value here causes illegal behavior
// :141:22: note: when computing vector element at index '0'
// :141:22: error: use of undefined value here causes illegal behavior
// :141:22: note: when computing vector element at index '0'
// :141:22: error: use of undefined value here causes illegal behavior
// :141:22: note: when computing vector element at index '0'
// :141:22: error: use of undefined value here causes illegal behavior
// :141:22: note: when computing vector element at index '1'
// :141:22: error: use of undefined value here causes illegal behavior
// :141:22: note: when computing vector element at index '0'
// :141:22: error: use of undefined value here causes illegal behavior
// :141:22: note: when computing vector element at index '0'
// :141:22: error: use of undefined value here causes illegal behavior
// :141:22: note: when computing vector element at index '0'
// :141:22: error: use of undefined value here causes illegal behavior
// :141:22: error: use of undefined value here causes illegal behavior
// :141:22: note: when computing vector element at index '0'
// :141:22: error: use of undefined value here causes illegal behavior
// :141:22: note: when computing vector element at index '0'
// :141:22: error: use of undefined value here causes illegal behavior
// :141:22: note: when computing vector element at index '0'
// :141:22: error: use of undefined value here causes illegal behavior
// :141:22: note: when computing vector element at index '1'
// :141:22: error: use of undefined value here causes illegal behavior
// :141:22: note: when computing vector element at index '0'
// :141:22: error: use of undefined value here causes illegal behavior
// :141:22: note: when computing vector element at index '0'
// :141:22: error: use of undefined value here causes illegal behavior
// :141:22: note: when computing vector element at index '0'
// :141:22: error: use of undefined value here causes illegal behavior
// :141:22: error: use of undefined value here causes illegal behavior
// :141:22: note: when computing vector element at index '0'
// :141:22: error: use of undefined value here causes illegal behavior
// :141:22: note: when computing vector element at index '0'
// :141:22: error: use of undefined value here causes illegal behavior
// :141:22: note: when computing vector element at index '0'
// :141:22: error: use of undefined value here causes illegal behavior
// :141:22: note: when computing vector element at index '1'
// :141:22: error: use of undefined value here causes illegal behavior
// :141:22: note: when computing vector element at index '0'
// :141:22: error: use of undefined value here causes illegal behavior
// :141:22: note: when computing vector element at index '0'
// :141:22: error: use of undefined value here causes illegal behavior
// :141:22: note: when computing vector element at index '0'
// :141:22: error: use of undefined value here causes illegal behavior
// :141:22: error: use of undefined value here causes illegal behavior
// :141:22: note: when computing vector element at index '0'
// :141:22: error: use of undefined value here causes illegal behavior
// :141:22: note: when computing vector element at index '0'
// :141:22: error: use of undefined value here causes illegal behavior
// :141:22: note: when computing vector element at index '0'
// :141:22: error: use of undefined value here causes illegal behavior
// :141:22: note: when computing vector element at index '1'
// :141:22: error: use of undefined value here causes illegal behavior
// :141:22: note: when computing vector element at index '0'
// :141:22: error: use of undefined value here causes illegal behavior
// :141:22: note: when computing vector element at index '0'
// :141:22: error: use of undefined value here causes illegal behavior
// :141:22: note: when computing vector element at index '0'
// :141:22: error: use of undefined value here causes illegal behavior
// :141:22: error: use of undefined value here causes illegal behavior
// :141:22: note: when computing vector element at index '0'
// :141:22: error: use of undefined value here causes illegal behavior
// :141:22: note: when computing vector element at index '0'
// :141:22: error: use of undefined value here causes illegal behavior
// :141:22: note: when computing vector element at index '0'
// :141:22: error: use of undefined value here causes illegal behavior
// :141:22: note: when computing vector element at index '1'
// :141:22: error: use of undefined value here causes illegal behavior
// :141:22: note: when computing vector element at index '0'
// :141:22: error: use of undefined value here causes illegal behavior
// :141:22: note: when computing vector element at index '0'
// :141:22: error: use of undefined value here causes illegal behavior
// :141:22: note: when computing vector element at index '0'
// :141:22: error: use of undefined value here causes illegal behavior
// :141:22: error: use of undefined value here causes illegal behavior
// :141:22: note: when computing vector element at index '0'
// :141:22: error: use of undefined value here causes illegal behavior
// :141:22: note: when computing vector element at index '0'
// :141:22: error: use of undefined value here causes illegal behavior
// :141:22: note: when computing vector element at index '0'
// :141:22: error: use of undefined value here causes illegal behavior
// :141:22: note: when computing vector element at index '1'
// :141:22: error: use of undefined value here causes illegal behavior
// :141:22: note: when computing vector element at index '0'
// :141:22: error: use of undefined value here causes illegal behavior
// :141:22: note: when computing vector element at index '0'
// :141:22: error: use of undefined value here causes illegal behavior
// :141:22: note: when computing vector element at index '0'
// :141:22: error: use of undefined value here causes illegal behavior
// :141:22: error: use of undefined value here causes illegal behavior
// :141:22: note: when computing vector element at index '0'
// :141:22: error: use of undefined value here causes illegal behavior
// :141:22: note: when computing vector element at index '0'
// :141:22: error: use of undefined value here causes illegal behavior
// :141:22: note: when computing vector element at index '0'
// :141:22: error: use of undefined value here causes illegal behavior
// :141:22: note: when computing vector element at index '1'
// :141:22: error: use of undefined value here causes illegal behavior
// :141:22: note: when computing vector element at index '0'
// :141:22: error: use of undefined value here causes illegal behavior
// :141:22: note: when computing vector element at index '0'
// :141:22: error: use of undefined value here causes illegal behavior
// :141:22: note: when computing vector element at index '0'
// :141:22: error: use of undefined value here causes illegal behavior
// :141:22: error: use of undefined value here causes illegal behavior
// :141:22: note: when computing vector element at index '0'
// :141:22: error: use of undefined value here causes illegal behavior
// :141:22: note: when computing vector element at index '0'
// :141:22: error: use of undefined value here causes illegal behavior
// :141:22: note: when computing vector element at index '0'
// :141:22: error: use of undefined value here causes illegal behavior
// :141:22: note: when computing vector element at index '1'
// :141:22: error: use of undefined value here causes illegal behavior
// :141:22: note: when computing vector element at index '0'
// :141:22: error: use of undefined value here causes illegal behavior
// :141:22: note: when computing vector element at index '0'
// :141:22: error: use of undefined value here causes illegal behavior
// :141:22: note: when computing vector element at index '0'
// :141:22: error: use of undefined value here causes illegal behavior
// :141:22: error: use of undefined value here causes illegal behavior
// :141:22: note: when computing vector element at index '0'
// :141:22: error: use of undefined value here causes illegal behavior
// :141:22: note: when computing vector element at index '0'
// :141:22: error: use of undefined value here causes illegal behavior
// :141:22: note: when computing vector element at index '0'
// :141:22: error: use of undefined value here causes illegal behavior
// :141:22: note: when computing vector element at index '1'
// :141:22: error: use of undefined value here causes illegal behavior
// :141:22: note: when computing vector element at index '0'
// :141:22: error: use of undefined value here causes illegal behavior
// :141:22: note: when computing vector element at index '0'
// :141:22: error: use of undefined value here causes illegal behavior
// :141:22: note: when computing vector element at index '0'
// :141:22: error: use of undefined value here causes illegal behavior
// :141:22: error: use of undefined value here causes illegal behavior
// :141:22: note: when computing vector element at index '0'
// :141:22: error: use of undefined value here causes illegal behavior
// :141:22: note: when computing vector element at index '0'
// :141:22: error: use of undefined value here causes illegal behavior
// :141:22: note: when computing vector element at index '0'
// :141:22: error: use of undefined value here causes illegal behavior
// :141:22: note: when computing vector element at index '1'
// :141:22: error: use of undefined value here causes illegal behavior
// :141:22: note: when computing vector element at index '0'
// :141:22: error: use of undefined value here causes illegal behavior
// :141:22: note: when computing vector element at index '0'
// :141:22: error: use of undefined value here causes illegal behavior
// :141:22: note: when computing vector element at index '0'
// :141:25: error: use of undefined value here causes illegal behavior
// :141:25: error: use of undefined value here causes illegal behavior
// :141:25: note: when computing vector element at index '0'
// :141:25: error: use of undefined value here causes illegal behavior
// :141:25: note: when computing vector element at index '0'
// :141:25: error: use of undefined value here causes illegal behavior
// :141:25: note: when computing vector element at index '1'
// :141:25: error: use of undefined value here causes illegal behavior
// :141:25: note: when computing vector element at index '0'
// :141:25: error: use of undefined value here causes illegal behavior
// :141:25: note: when computing vector element at index '0'
// :141:25: error: use of undefined value here causes illegal behavior
// :141:25: error: use of undefined value here causes illegal behavior
// :141:25: note: when computing vector element at index '0'
// :141:25: error: use of undefined value here causes illegal behavior
// :141:25: note: when computing vector element at index '0'
// :141:25: error: use of undefined value here causes illegal behavior
// :141:25: note: when computing vector element at index '1'
// :141:25: error: use of undefined value here causes illegal behavior
// :141:25: note: when computing vector element at index '0'
// :141:25: error: use of undefined value here causes illegal behavior
// :141:25: note: when computing vector element at index '0'
// :141:25: error: use of undefined value here causes illegal behavior
// :141:25: error: use of undefined value here causes illegal behavior
// :141:25: note: when computing vector element at index '0'
// :141:25: error: use of undefined value here causes illegal behavior
// :141:25: note: when computing vector element at index '0'
// :141:25: error: use of undefined value here causes illegal behavior
// :141:25: note: when computing vector element at index '1'
// :141:25: error: use of undefined value here causes illegal behavior
// :141:25: note: when computing vector element at index '0'
// :141:25: error: use of undefined value here causes illegal behavior
// :141:25: note: when computing vector element at index '0'
// :141:25: error: use of undefined value here causes illegal behavior
// :141:25: error: use of undefined value here causes illegal behavior
// :141:25: note: when computing vector element at index '0'
// :141:25: error: use of undefined value here causes illegal behavior
// :141:25: note: when computing vector element at index '0'
// :141:25: error: use of undefined value here causes illegal behavior
// :141:25: note: when computing vector element at index '1'
// :141:25: error: use of undefined value here causes illegal behavior
// :141:25: note: when computing vector element at index '0'
// :141:25: error: use of undefined value here causes illegal behavior
// :141:25: note: when computing vector element at index '0'
// :141:25: error: use of undefined value here causes illegal behavior
// :141:25: error: use of undefined value here causes illegal behavior
// :141:25: note: when computing vector element at index '0'
// :141:25: error: use of undefined value here causes illegal behavior
// :141:25: note: when computing vector element at index '0'
// :141:25: error: use of undefined value here causes illegal behavior
// :141:25: note: when computing vector element at index '1'
// :141:25: error: use of undefined value here causes illegal behavior
// :141:25: note: when computing vector element at index '0'
// :141:25: error: use of undefined value here causes illegal behavior
// :141:25: note: when computing vector element at index '0'
// :141:25: error: use of undefined value here causes illegal behavior
// :141:25: error: use of undefined value here causes illegal behavior
// :141:25: note: when computing vector element at index '0'
// :141:25: error: use of undefined value here causes illegal behavior
// :141:25: note: when computing vector element at index '0'
// :141:25: error: use of undefined value here causes illegal behavior
// :141:25: note: when computing vector element at index '1'
// :141:25: error: use of undefined value here causes illegal behavior
// :141:25: note: when computing vector element at index '0'
// :141:25: error: use of undefined value here causes illegal behavior
// :141:25: note: when computing vector element at index '0'
// :141:25: error: use of undefined value here causes illegal behavior
// :141:25: error: use of undefined value here causes illegal behavior
// :141:25: note: when computing vector element at index '0'
// :141:25: error: use of undefined value here causes illegal behavior
// :141:25: note: when computing vector element at index '0'
// :141:25: error: use of undefined value here causes illegal behavior
// :141:25: note: when computing vector element at index '1'
// :141:25: error: use of undefined value here causes illegal behavior
// :141:25: note: when computing vector element at index '0'
// :141:25: error: use of undefined value here causes illegal behavior
// :141:25: note: when computing vector element at index '0'
// :141:25: error: use of undefined value here causes illegal behavior
// :141:25: error: use of undefined value here causes illegal behavior
// :141:25: note: when computing vector element at index '0'
// :141:25: error: use of undefined value here causes illegal behavior
// :141:25: note: when computing vector element at index '0'
// :141:25: error: use of undefined value here causes illegal behavior
// :141:25: note: when computing vector element at index '1'
// :141:25: error: use of undefined value here causes illegal behavior
// :141:25: note: when computing vector element at index '0'
// :141:25: error: use of undefined value here causes illegal behavior
// :141:25: note: when computing vector element at index '0'
// :141:25: error: use of undefined value here causes illegal behavior
// :141:25: error: use of undefined value here causes illegal behavior
// :141:25: note: when computing vector element at index '0'
// :141:25: error: use of undefined value here causes illegal behavior
// :141:25: note: when computing vector element at index '0'
// :141:25: error: use of undefined value here causes illegal behavior
// :141:25: note: when computing vector element at index '1'
// :141:25: error: use of undefined value here causes illegal behavior
// :141:25: note: when computing vector element at index '0'
// :141:25: error: use of undefined value here causes illegal behavior
// :141:25: note: when computing vector element at index '0'
// :141:25: error: use of undefined value here causes illegal behavior
// :141:25: error: use of undefined value here causes illegal behavior
// :141:25: note: when computing vector element at index '0'
// :141:25: error: use of undefined value here causes illegal behavior
// :141:25: note: when computing vector element at index '0'
// :141:25: error: use of undefined value here causes illegal behavior
// :141:25: note: when computing vector element at index '1'
// :141:25: error: use of undefined value here causes illegal behavior
// :141:25: note: when computing vector element at index '0'
// :141:25: error: use of undefined value here causes illegal behavior
// :141:25: note: when computing vector element at index '0'
// :141:25: error: use of undefined value here causes illegal behavior
// :141:25: error: use of undefined value here causes illegal behavior
// :141:25: note: when computing vector element at index '0'
// :141:25: error: use of undefined value here causes illegal behavior
// :141:25: note: when computing vector element at index '0'
// :141:25: error: use of undefined value here causes illegal behavior
// :141:25: note: when computing vector element at index '1'
// :141:25: error: use of undefined value here causes illegal behavior
// :141:25: note: when computing vector element at index '0'
// :141:25: error: use of undefined value here causes illegal behavior
// :141:25: note: when computing vector element at index '0'
// :145:22: error: use of undefined value here causes illegal behavior
// :145:22: error: use of undefined value here causes illegal behavior
// :145:22: note: when computing vector element at index '0'
// :145:22: error: use of undefined value here causes illegal behavior
// :145:22: note: when computing vector element at index '0'
// :145:22: error: use of undefined value here causes illegal behavior
// :145:22: note: when computing vector element at index '0'
// :145:22: error: use of undefined value here causes illegal behavior
// :145:22: note: when computing vector element at index '1'
// :145:22: error: use of undefined value here causes illegal behavior
// :145:22: note: when computing vector element at index '0'
// :145:22: error: use of undefined value here causes illegal behavior
// :145:22: note: when computing vector element at index '0'
// :145:22: error: use of undefined value here causes illegal behavior
// :145:22: note: when computing vector element at index '0'
// :145:22: error: use of undefined value here causes illegal behavior
// :145:22: error: use of undefined value here causes illegal behavior
// :145:22: note: when computing vector element at index '0'
// :145:22: error: use of undefined value here causes illegal behavior
// :145:22: note: when computing vector element at index '0'
// :145:22: error: use of undefined value here causes illegal behavior
// :145:22: note: when computing vector element at index '0'
// :145:22: error: use of undefined value here causes illegal behavior
// :145:22: note: when computing vector element at index '1'
// :145:22: error: use of undefined value here causes illegal behavior
// :145:22: note: when computing vector element at index '0'
// :145:22: error: use of undefined value here causes illegal behavior
// :145:22: note: when computing vector element at index '0'
// :145:22: error: use of undefined value here causes illegal behavior
// :145:22: note: when computing vector element at index '0'
// :145:22: error: use of undefined value here causes illegal behavior
// :145:22: error: use of undefined value here causes illegal behavior
// :145:22: note: when computing vector element at index '0'
// :145:22: error: use of undefined value here causes illegal behavior
// :145:22: note: when computing vector element at index '0'
// :145:22: error: use of undefined value here causes illegal behavior
// :145:22: note: when computing vector element at index '0'
// :145:22: error: use of undefined value here causes illegal behavior
// :145:22: note: when computing vector element at index '1'
// :145:22: error: use of undefined value here causes illegal behavior
// :145:22: note: when computing vector element at index '0'
// :145:22: error: use of undefined value here causes illegal behavior
// :145:22: note: when computing vector element at index '0'
// :145:22: error: use of undefined value here causes illegal behavior
// :145:22: note: when computing vector element at index '0'
// :145:22: error: use of undefined value here causes illegal behavior
// :145:22: error: use of undefined value here causes illegal behavior
// :145:22: note: when computing vector element at index '0'
// :145:22: error: use of undefined value here causes illegal behavior
// :145:22: note: when computing vector element at index '0'
// :145:22: error: use of undefined value here causes illegal behavior
// :145:22: note: when computing vector element at index '0'
// :145:22: error: use of undefined value here causes illegal behavior
// :145:22: note: when computing vector element at index '1'
// :145:22: error: use of undefined value here causes illegal behavior
// :145:22: note: when computing vector element at index '0'
// :145:22: error: use of undefined value here causes illegal behavior
// :145:22: note: when computing vector element at index '0'
// :145:22: error: use of undefined value here causes illegal behavior
// :145:22: note: when computing vector element at index '0'
// :145:22: error: use of undefined value here causes illegal behavior
// :145:22: error: use of undefined value here causes illegal behavior
// :145:22: note: when computing vector element at index '0'
// :145:22: error: use of undefined value here causes illegal behavior
// :145:22: note: when computing vector element at index '0'
// :145:22: error: use of undefined value here causes illegal behavior
// :145:22: note: when computing vector element at index '0'
// :145:22: error: use of undefined value here causes illegal behavior
// :145:22: note: when computing vector element at index '1'
// :145:22: error: use of undefined value here causes illegal behavior
// :145:22: note: when computing vector element at index '0'
// :145:22: error: use of undefined value here causes illegal behavior
// :145:22: note: when computing vector element at index '0'
// :145:22: error: use of undefined value here causes illegal behavior
// :145:22: note: when computing vector element at index '0'
// :145:22: error: use of undefined value here causes illegal behavior
// :145:22: error: use of undefined value here causes illegal behavior
// :145:22: note: when computing vector element at index '0'
// :145:22: error: use of undefined value here causes illegal behavior
// :145:22: note: when computing vector element at index '0'
// :145:22: error: use of undefined value here causes illegal behavior
// :145:22: note: when computing vector element at index '0'
// :145:22: error: use of undefined value here causes illegal behavior
// :145:22: note: when computing vector element at index '1'
// :145:22: error: use of undefined value here causes illegal behavior
// :145:22: note: when computing vector element at index '0'
// :145:22: error: use of undefined value here causes illegal behavior
// :145:22: note: when computing vector element at index '0'
// :145:22: error: use of undefined value here causes illegal behavior
// :145:22: note: when computing vector element at index '0'
// :145:22: error: use of undefined value here causes illegal behavior
// :145:22: error: use of undefined value here causes illegal behavior
// :145:22: note: when computing vector element at index '0'
// :145:22: error: use of undefined value here causes illegal behavior
// :145:22: note: when computing vector element at index '0'
// :145:22: error: use of undefined value here causes illegal behavior
// :145:22: note: when computing vector element at index '0'
// :145:22: error: use of undefined value here causes illegal behavior
// :145:22: note: when computing vector element at index '1'
// :145:22: error: use of undefined value here causes illegal behavior
// :145:22: note: when computing vector element at index '0'
// :145:22: error: use of undefined value here causes illegal behavior
// :145:22: note: when computing vector element at index '0'
// :145:22: error: use of undefined value here causes illegal behavior
// :145:22: note: when computing vector element at index '0'
// :145:22: error: use of undefined value here causes illegal behavior
// :145:22: error: use of undefined value here causes illegal behavior
// :145:22: note: when computing vector element at index '0'
// :145:22: error: use of undefined value here causes illegal behavior
// :145:22: note: when computing vector element at index '0'
// :145:22: error: use of undefined value here causes illegal behavior
// :145:22: note: when computing vector element at index '0'
// :145:22: error: use of undefined value here causes illegal behavior
// :145:22: note: when computing vector element at index '1'
// :145:22: error: use of undefined value here causes illegal behavior
// :145:22: note: when computing vector element at index '0'
// :145:22: error: use of undefined value here causes illegal behavior
// :145:22: note: when computing vector element at index '0'
// :145:22: error: use of undefined value here causes illegal behavior
// :145:22: note: when computing vector element at index '0'
// :145:22: error: use of undefined value here causes illegal behavior
// :145:22: error: use of undefined value here causes illegal behavior
// :145:22: note: when computing vector element at index '0'
// :145:22: error: use of undefined value here causes illegal behavior
// :145:22: note: when computing vector element at index '0'
// :145:22: error: use of undefined value here causes illegal behavior
// :145:22: note: when computing vector element at index '0'
// :145:22: error: use of undefined value here causes illegal behavior
// :145:22: note: when computing vector element at index '1'
// :145:22: error: use of undefined value here causes illegal behavior
// :145:22: note: when computing vector element at index '0'
// :145:22: error: use of undefined value here causes illegal behavior
// :145:22: note: when computing vector element at index '0'
// :145:22: error: use of undefined value here causes illegal behavior
// :145:22: note: when computing vector element at index '0'
// :145:22: error: use of undefined value here causes illegal behavior
// :145:22: error: use of undefined value here causes illegal behavior
// :145:22: note: when computing vector element at index '0'
// :145:22: error: use of undefined value here causes illegal behavior
// :145:22: note: when computing vector element at index '0'
// :145:22: error: use of undefined value here causes illegal behavior
// :145:22: note: when computing vector element at index '0'
// :145:22: error: use of undefined value here causes illegal behavior
// :145:22: note: when computing vector element at index '1'
// :145:22: error: use of undefined value here causes illegal behavior
// :145:22: note: when computing vector element at index '0'
// :145:22: error: use of undefined value here causes illegal behavior
// :145:22: note: when computing vector element at index '0'
// :145:22: error: use of undefined value here causes illegal behavior
// :145:22: note: when computing vector element at index '0'
// :145:22: error: use of undefined value here causes illegal behavior
// :145:22: error: use of undefined value here causes illegal behavior
// :145:22: note: when computing vector element at index '0'
// :145:22: error: use of undefined value here causes illegal behavior
// :145:22: note: when computing vector element at index '0'
// :145:22: error: use of undefined value here causes illegal behavior
// :145:22: note: when computing vector element at index '0'
// :145:22: error: use of undefined value here causes illegal behavior
// :145:22: note: when computing vector element at index '1'
// :145:22: error: use of undefined value here causes illegal behavior
// :145:22: note: when computing vector element at index '0'
// :145:22: error: use of undefined value here causes illegal behavior
// :145:22: note: when computing vector element at index '0'
// :145:22: error: use of undefined value here causes illegal behavior
// :145:22: note: when computing vector element at index '0'
// :145:25: error: use of undefined value here causes illegal behavior
// :145:25: error: use of undefined value here causes illegal behavior
// :145:25: note: when computing vector element at index '0'
// :145:25: error: use of undefined value here causes illegal behavior
// :145:25: note: when computing vector element at index '0'
// :145:25: error: use of undefined value here causes illegal behavior
// :145:25: note: when computing vector element at index '1'
// :145:25: error: use of undefined value here causes illegal behavior
// :145:25: note: when computing vector element at index '0'
// :145:25: error: use of undefined value here causes illegal behavior
// :145:25: note: when computing vector element at index '0'
// :145:25: error: use of undefined value here causes illegal behavior
// :145:25: error: use of undefined value here causes illegal behavior
// :145:25: note: when computing vector element at index '0'
// :145:25: error: use of undefined value here causes illegal behavior
// :145:25: note: when computing vector element at index '0'
// :145:25: error: use of undefined value here causes illegal behavior
// :145:25: note: when computing vector element at index '1'
// :145:25: error: use of undefined value here causes illegal behavior
// :145:25: note: when computing vector element at index '0'
// :145:25: error: use of undefined value here causes illegal behavior
// :145:25: note: when computing vector element at index '0'
// :145:25: error: use of undefined value here causes illegal behavior
// :145:25: error: use of undefined value here causes illegal behavior
// :145:25: note: when computing vector element at index '0'
// :145:25: error: use of undefined value here causes illegal behavior
// :145:25: note: when computing vector element at index '0'
// :145:25: error: use of undefined value here causes illegal behavior
// :145:25: note: when computing vector element at index '1'
// :145:25: error: use of undefined value here causes illegal behavior
// :145:25: note: when computing vector element at index '0'
// :145:25: error: use of undefined value here causes illegal behavior
// :145:25: note: when computing vector element at index '0'
// :145:25: error: use of undefined value here causes illegal behavior
// :145:25: error: use of undefined value here causes illegal behavior
// :145:25: note: when computing vector element at index '0'
// :145:25: error: use of undefined value here causes illegal behavior
// :145:25: note: when computing vector element at index '0'
// :145:25: error: use of undefined value here causes illegal behavior
// :145:25: note: when computing vector element at index '1'
// :145:25: error: use of undefined value here causes illegal behavior
// :145:25: note: when computing vector element at index '0'
// :145:25: error: use of undefined value here causes illegal behavior
// :145:25: note: when computing vector element at index '0'
// :145:25: error: use of undefined value here causes illegal behavior
// :145:25: error: use of undefined value here causes illegal behavior
// :145:25: note: when computing vector element at index '0'
// :145:25: error: use of undefined value here causes illegal behavior
// :145:25: note: when computing vector element at index '0'
// :145:25: error: use of undefined value here causes illegal behavior
// :145:25: note: when computing vector element at index '1'
// :145:25: error: use of undefined value here causes illegal behavior
// :145:25: note: when computing vector element at index '0'
// :145:25: error: use of undefined value here causes illegal behavior
// :145:25: note: when computing vector element at index '0'
// :145:25: error: use of undefined value here causes illegal behavior
// :145:25: error: use of undefined value here causes illegal behavior
// :145:25: note: when computing vector element at index '0'
// :145:25: error: use of undefined value here causes illegal behavior
// :145:25: note: when computing vector element at index '0'
// :145:25: error: use of undefined value here causes illegal behavior
// :145:25: note: when computing vector element at index '1'
// :145:25: error: use of undefined value here causes illegal behavior
// :145:25: note: when computing vector element at index '0'
// :145:25: error: use of undefined value here causes illegal behavior
// :145:25: note: when computing vector element at index '0'
// :145:25: error: use of undefined value here causes illegal behavior
// :145:25: error: use of undefined value here causes illegal behavior
// :145:25: note: when computing vector element at index '0'
// :145:25: error: use of undefined value here causes illegal behavior
// :145:25: note: when computing vector element at index '0'
// :145:25: error: use of undefined value here causes illegal behavior
// :145:25: note: when computing vector element at index '1'
// :145:25: error: use of undefined value here causes illegal behavior
// :145:25: note: when computing vector element at index '0'
// :145:25: error: use of undefined value here causes illegal behavior
// :145:25: note: when computing vector element at index '0'
// :145:25: error: use of undefined value here causes illegal behavior
// :145:25: error: use of undefined value here causes illegal behavior
// :145:25: note: when computing vector element at index '0'
// :145:25: error: use of undefined value here causes illegal behavior
// :145:25: note: when computing vector element at index '0'
// :145:25: error: use of undefined value here causes illegal behavior
// :145:25: note: when computing vector element at index '1'
// :145:25: error: use of undefined value here causes illegal behavior
// :145:25: note: when computing vector element at index '0'
// :145:25: error: use of undefined value here causes illegal behavior
// :145:25: note: when computing vector element at index '0'
// :145:25: error: use of undefined value here causes illegal behavior
// :145:25: error: use of undefined value here causes illegal behavior
// :145:25: note: when computing vector element at index '0'
// :145:25: error: use of undefined value here causes illegal behavior
// :145:25: note: when computing vector element at index '0'
// :145:25: error: use of undefined value here causes illegal behavior
// :145:25: note: when computing vector element at index '1'
// :145:25: error: use of undefined value here causes illegal behavior
// :145:25: note: when computing vector element at index '0'
// :145:25: error: use of undefined value here causes illegal behavior
// :145:25: note: when computing vector element at index '0'
// :145:25: error: use of undefined value here causes illegal behavior
// :145:25: error: use of undefined value here causes illegal behavior
// :145:25: note: when computing vector element at index '0'
// :145:25: error: use of undefined value here causes illegal behavior
// :145:25: note: when computing vector element at index '0'
// :145:25: error: use of undefined value here causes illegal behavior
// :145:25: note: when computing vector element at index '1'
// :145:25: error: use of undefined value here causes illegal behavior
// :145:25: note: when computing vector element at index '0'
// :145:25: error: use of undefined value here causes illegal behavior
// :145:25: note: when computing vector element at index '0'
// :145:25: error: use of undefined value here causes illegal behavior
// :145:25: error: use of undefined value here causes illegal behavior
// :145:25: note: when computing vector element at index '0'
// :145:25: error: use of undefined value here causes illegal behavior
// :145:25: note: when computing vector element at index '0'
// :145:25: error: use of undefined value here causes illegal behavior
// :145:25: note: when computing vector element at index '1'
// :145:25: error: use of undefined value here causes illegal behavior
// :145:25: note: when computing vector element at index '0'
// :145:25: error: use of undefined value here causes illegal behavior
// :145:25: note: when computing vector element at index '0'
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: note: when computing vector element at index '1'
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: note: when computing vector element at index '1'
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: note: when computing vector element at index '1'
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: note: when computing vector element at index '1'
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: note: when computing vector element at index '0'
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: note: when computing vector element at index '0'
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: note: when computing vector element at index '0'
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: note: when computing vector element at index '0'
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: note: when computing vector element at index '1'
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: note: when computing vector element at index '1'
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: note: when computing vector element at index '1'
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: note: when computing vector element at index '1'
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: note: when computing vector element at index '0'
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: note: when computing vector element at index '0'
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: note: when computing vector element at index '0'
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: note: when computing vector element at index '0'
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: note: when computing vector element at index '1'
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: note: when computing vector element at index '1'
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: note: when computing vector element at index '1'
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: note: when computing vector element at index '1'
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: note: when computing vector element at index '0'
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: note: when computing vector element at index '0'
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: note: when computing vector element at index '0'
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: note: when computing vector element at index '0'
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: note: when computing vector element at index '1'
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: note: when computing vector element at index '1'
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: note: when computing vector element at index '1'
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: note: when computing vector element at index '1'
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: note: when computing vector element at index '0'
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: note: when computing vector element at index '0'
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: note: when computing vector element at index '0'
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: note: when computing vector element at index '0'
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: note: when computing vector element at index '1'
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: note: when computing vector element at index '1'
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: note: when computing vector element at index '1'
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: note: when computing vector element at index '1'
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: note: when computing vector element at index '0'
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: note: when computing vector element at index '0'
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: note: when computing vector element at index '0'
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: note: when computing vector element at index '0'
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: note: when computing vector element at index '1'
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: note: when computing vector element at index '1'
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: note: when computing vector element at index '1'
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: note: when computing vector element at index '1'
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: note: when computing vector element at index '0'
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: note: when computing vector element at index '0'
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: note: when computing vector element at index '0'
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: note: when computing vector element at index '0'
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: note: when computing vector element at index '1'
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: note: when computing vector element at index '1'
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: note: when computing vector element at index '1'
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: note: when computing vector element at index '1'
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: note: when computing vector element at index '0'
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: note: when computing vector element at index '0'
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: note: when computing vector element at index '0'
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: note: when computing vector element at index '0'
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: note: when computing vector element at index '1'
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: note: when computing vector element at index '1'
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: note: when computing vector element at index '1'
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: note: when computing vector element at index '1'
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: note: when computing vector element at index '0'
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: note: when computing vector element at index '0'
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: note: when computing vector element at index '0'
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: note: when computing vector element at index '0'
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: note: when computing vector element at index '1'
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: note: when computing vector element at index '1'
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: note: when computing vector element at index '1'
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: note: when computing vector element at index '1'
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: note: when computing vector element at index '0'
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: note: when computing vector element at index '0'
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: note: when computing vector element at index '0'
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: note: when computing vector element at index '0'
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: note: when computing vector element at index '1'
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: note: when computing vector element at index '1'
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: note: when computing vector element at index '1'
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: note: when computing vector element at index '1'
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: note: when computing vector element at index '0'
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: note: when computing vector element at index '0'
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: note: when computing vector element at index '0'
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: note: when computing vector element at index '0'
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: note: when computing vector element at index '1'
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: note: when computing vector element at index '1'
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: note: when computing vector element at index '1'
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: note: when computing vector element at index '1'
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: note: when computing vector element at index '0'
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: note: when computing vector element at index '0'
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: note: when computing vector element at index '0'
// :151:21: error: use of undefined value here causes illegal behavior
// :151:21: note: when computing vector element at index '0'
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: note: when computing vector element at index '1'
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: note: when computing vector element at index '1'
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: note: when computing vector element at index '1'
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: note: when computing vector element at index '1'
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: note: when computing vector element at index '0'
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: note: when computing vector element at index '0'
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: note: when computing vector element at index '0'
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: note: when computing vector element at index '0'
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: note: when computing vector element at index '1'
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: note: when computing vector element at index '1'
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: note: when computing vector element at index '1'
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: note: when computing vector element at index '1'
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: note: when computing vector element at index '0'
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: note: when computing vector element at index '0'
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: note: when computing vector element at index '0'
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: note: when computing vector element at index '0'
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: note: when computing vector element at index '1'
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: note: when computing vector element at index '1'
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: note: when computing vector element at index '1'
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: note: when computing vector element at index '1'
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: note: when computing vector element at index '0'
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: note: when computing vector element at index '0'
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: note: when computing vector element at index '0'
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: note: when computing vector element at index '0'
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: note: when computing vector element at index '1'
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: note: when computing vector element at index '1'
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: note: when computing vector element at index '1'
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: note: when computing vector element at index '1'
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: note: when computing vector element at index '0'
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: note: when computing vector element at index '0'
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: note: when computing vector element at index '0'
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: note: when computing vector element at index '0'
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: note: when computing vector element at index '1'
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: note: when computing vector element at index '1'
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: note: when computing vector element at index '1'
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: note: when computing vector element at index '1'
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: note: when computing vector element at index '0'
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: note: when computing vector element at index '0'
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: note: when computing vector element at index '0'
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: note: when computing vector element at index '0'
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: note: when computing vector element at index '1'
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: note: when computing vector element at index '1'
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: note: when computing vector element at index '1'
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: note: when computing vector element at index '1'
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: note: when computing vector element at index '0'
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: note: when computing vector element at index '0'
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: note: when computing vector element at index '0'
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: note: when computing vector element at index '0'
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: note: when computing vector element at index '1'
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: note: when computing vector element at index '1'
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: note: when computing vector element at index '1'
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: note: when computing vector element at index '1'
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: note: when computing vector element at index '0'
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: note: when computing vector element at index '0'
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: note: when computing vector element at index '0'
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: note: when computing vector element at index '0'
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: note: when computing vector element at index '1'
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: note: when computing vector element at index '1'
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: note: when computing vector element at index '1'
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: note: when computing vector element at index '1'
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: note: when computing vector element at index '0'
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: note: when computing vector element at index '0'
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: note: when computing vector element at index '0'
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: note: when computing vector element at index '0'
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: note: when computing vector element at index '1'
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: note: when computing vector element at index '1'
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: note: when computing vector element at index '1'
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: note: when computing vector element at index '1'
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: note: when computing vector element at index '0'
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: note: when computing vector element at index '0'
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: note: when computing vector element at index '0'
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: note: when computing vector element at index '0'
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: note: when computing vector element at index '1'
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: note: when computing vector element at index '1'
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: note: when computing vector element at index '1'
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: note: when computing vector element at index '1'
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: note: when computing vector element at index '0'
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: note: when computing vector element at index '0'
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: note: when computing vector element at index '0'
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: note: when computing vector element at index '0'
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: note: when computing vector element at index '1'
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: note: when computing vector element at index '1'
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: note: when computing vector element at index '1'
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: note: when computing vector element at index '1'
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: note: when computing vector element at index '0'
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: note: when computing vector element at index '0'
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: note: when computing vector element at index '0'
// :155:30: error: use of undefined value here causes illegal behavior
// :155:30: note: when computing vector element at index '0'
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: note: when computing vector element at index '1'
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: note: when computing vector element at index '1'
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: note: when computing vector element at index '1'
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: note: when computing vector element at index '1'
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: note: when computing vector element at index '0'
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: note: when computing vector element at index '0'
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: note: when computing vector element at index '0'
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: note: when computing vector element at index '0'
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: note: when computing vector element at index '1'
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: note: when computing vector element at index '1'
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: note: when computing vector element at index '1'
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: note: when computing vector element at index '1'
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: note: when computing vector element at index '0'
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: note: when computing vector element at index '0'
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: note: when computing vector element at index '0'
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: note: when computing vector element at index '0'
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: note: when computing vector element at index '1'
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: note: when computing vector element at index '1'
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: note: when computing vector element at index '1'
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: note: when computing vector element at index '1'
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: note: when computing vector element at index '0'
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: note: when computing vector element at index '0'
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: note: when computing vector element at index '0'
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: note: when computing vector element at index '0'
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: note: when computing vector element at index '1'
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: note: when computing vector element at index '1'
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: note: when computing vector element at index '1'
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: note: when computing vector element at index '1'
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: note: when computing vector element at index '0'
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: note: when computing vector element at index '0'
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: note: when computing vector element at index '0'
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: note: when computing vector element at index '0'
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: note: when computing vector element at index '1'
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: note: when computing vector element at index '1'
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: note: when computing vector element at index '1'
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: note: when computing vector element at index '1'
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: note: when computing vector element at index '0'
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: note: when computing vector element at index '0'
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: note: when computing vector element at index '0'
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: note: when computing vector element at index '0'
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: note: when computing vector element at index '1'
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: note: when computing vector element at index '1'
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: note: when computing vector element at index '1'
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: note: when computing vector element at index '1'
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: note: when computing vector element at index '0'
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: note: when computing vector element at index '0'
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: note: when computing vector element at index '0'
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: note: when computing vector element at index '0'
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: note: when computing vector element at index '1'
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: note: when computing vector element at index '1'
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: note: when computing vector element at index '1'
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: note: when computing vector element at index '1'
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: note: when computing vector element at index '0'
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: note: when computing vector element at index '0'
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: note: when computing vector element at index '0'
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: note: when computing vector element at index '0'
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: note: when computing vector element at index '1'
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: note: when computing vector element at index '1'
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: note: when computing vector element at index '1'
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: note: when computing vector element at index '1'
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: note: when computing vector element at index '0'
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: note: when computing vector element at index '0'
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: note: when computing vector element at index '0'
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: note: when computing vector element at index '0'
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: note: when computing vector element at index '1'
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: note: when computing vector element at index '1'
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: note: when computing vector element at index '1'
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: note: when computing vector element at index '1'
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: note: when computing vector element at index '0'
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: note: when computing vector element at index '0'
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: note: when computing vector element at index '0'
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: note: when computing vector element at index '0'
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: note: when computing vector element at index '1'
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: note: when computing vector element at index '1'
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: note: when computing vector element at index '1'
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: note: when computing vector element at index '1'
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: note: when computing vector element at index '0'
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: note: when computing vector element at index '0'
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: note: when computing vector element at index '0'
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: note: when computing vector element at index '0'
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: note: when computing vector element at index '1'
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: note: when computing vector element at index '1'
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: note: when computing vector element at index '1'
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: note: when computing vector element at index '1'
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: note: when computing vector element at index '0'
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: note: when computing vector element at index '0'
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: note: when computing vector element at index '0'
// :159:30: error: use of undefined value here causes illegal behavior
// :159:30: note: when computing vector element at index '0'
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: note: when computing vector element at index '1'
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: note: when computing vector element at index '1'
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: note: when computing vector element at index '1'
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: note: when computing vector element at index '1'
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: note: when computing vector element at index '0'
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: note: when computing vector element at index '0'
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: note: when computing vector element at index '0'
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: note: when computing vector element at index '0'
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: note: when computing vector element at index '1'
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: note: when computing vector element at index '1'
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: note: when computing vector element at index '1'
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: note: when computing vector element at index '1'
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: note: when computing vector element at index '0'
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: note: when computing vector element at index '0'
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: note: when computing vector element at index '0'
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: note: when computing vector element at index '0'
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: note: when computing vector element at index '1'
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: note: when computing vector element at index '1'
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: note: when computing vector element at index '1'
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: note: when computing vector element at index '1'
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: note: when computing vector element at index '0'
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: note: when computing vector element at index '0'
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: note: when computing vector element at index '0'
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: note: when computing vector element at index '0'
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: note: when computing vector element at index '1'
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: note: when computing vector element at index '1'
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: note: when computing vector element at index '1'
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: note: when computing vector element at index '1'
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: note: when computing vector element at index '0'
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: note: when computing vector element at index '0'
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: note: when computing vector element at index '0'
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: note: when computing vector element at index '0'
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: note: when computing vector element at index '1'
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: note: when computing vector element at index '1'
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: note: when computing vector element at index '1'
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: note: when computing vector element at index '1'
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: note: when computing vector element at index '0'
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: note: when computing vector element at index '0'
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: note: when computing vector element at index '0'
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: note: when computing vector element at index '0'
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: note: when computing vector element at index '1'
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: note: when computing vector element at index '1'
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: note: when computing vector element at index '1'
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: note: when computing vector element at index '1'
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: note: when computing vector element at index '0'
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: note: when computing vector element at index '0'
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: note: when computing vector element at index '0'
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: note: when computing vector element at index '0'
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: note: when computing vector element at index '1'
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: note: when computing vector element at index '1'
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: note: when computing vector element at index '1'
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: note: when computing vector element at index '1'
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: note: when computing vector element at index '0'
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: note: when computing vector element at index '0'
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: note: when computing vector element at index '0'
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: note: when computing vector element at index '0'
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: note: when computing vector element at index '1'
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: note: when computing vector element at index '1'
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: note: when computing vector element at index '1'
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: note: when computing vector element at index '1'
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: note: when computing vector element at index '0'
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: note: when computing vector element at index '0'
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: note: when computing vector element at index '0'
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: note: when computing vector element at index '0'
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: note: when computing vector element at index '1'
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: note: when computing vector element at index '1'
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: note: when computing vector element at index '1'
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: note: when computing vector element at index '1'
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: note: when computing vector element at index '0'
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: note: when computing vector element at index '0'
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: note: when computing vector element at index '0'
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: note: when computing vector element at index '0'
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: note: when computing vector element at index '1'
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: note: when computing vector element at index '1'
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: note: when computing vector element at index '1'
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: note: when computing vector element at index '1'
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: note: when computing vector element at index '0'
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: note: when computing vector element at index '0'
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: note: when computing vector element at index '0'
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: note: when computing vector element at index '0'
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: note: when computing vector element at index '1'
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: note: when computing vector element at index '1'
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: note: when computing vector element at index '1'
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: note: when computing vector element at index '1'
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: note: when computing vector element at index '0'
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: note: when computing vector element at index '0'
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: note: when computing vector element at index '0'
// :163:30: error: use of undefined value here causes illegal behavior
// :163:30: note: when computing vector element at index '0'
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: note: when computing vector element at index '1'
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: note: when computing vector element at index '1'
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: note: when computing vector element at index '1'
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: note: when computing vector element at index '1'
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: note: when computing vector element at index '0'
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: note: when computing vector element at index '0'
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: note: when computing vector element at index '0'
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: note: when computing vector element at index '0'
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: note: when computing vector element at index '1'
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: note: when computing vector element at index '1'
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: note: when computing vector element at index '1'
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: note: when computing vector element at index '1'
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: note: when computing vector element at index '0'
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: note: when computing vector element at index '0'
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: note: when computing vector element at index '0'
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: note: when computing vector element at index '0'
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: note: when computing vector element at index '1'
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: note: when computing vector element at index '1'
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: note: when computing vector element at index '1'
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: note: when computing vector element at index '1'
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: note: when computing vector element at index '0'
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: note: when computing vector element at index '0'
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: note: when computing vector element at index '0'
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: note: when computing vector element at index '0'
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: note: when computing vector element at index '1'
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: note: when computing vector element at index '1'
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: note: when computing vector element at index '1'
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: note: when computing vector element at index '1'
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: note: when computing vector element at index '0'
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: note: when computing vector element at index '0'
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: note: when computing vector element at index '0'
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: note: when computing vector element at index '0'
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: note: when computing vector element at index '1'
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: note: when computing vector element at index '1'
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: note: when computing vector element at index '1'
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: note: when computing vector element at index '1'
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: note: when computing vector element at index '0'
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: note: when computing vector element at index '0'
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: note: when computing vector element at index '0'
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: note: when computing vector element at index '0'
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: note: when computing vector element at index '1'
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: note: when computing vector element at index '1'
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: note: when computing vector element at index '1'
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: note: when computing vector element at index '1'
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: note: when computing vector element at index '0'
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: note: when computing vector element at index '0'
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: note: when computing vector element at index '0'
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: note: when computing vector element at index '0'
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: note: when computing vector element at index '1'
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: note: when computing vector element at index '1'
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: note: when computing vector element at index '1'
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: note: when computing vector element at index '1'
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: note: when computing vector element at index '0'
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: note: when computing vector element at index '0'
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: note: when computing vector element at index '0'
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: note: when computing vector element at index '0'
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: note: when computing vector element at index '1'
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: note: when computing vector element at index '1'
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: note: when computing vector element at index '1'
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: note: when computing vector element at index '1'
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: note: when computing vector element at index '0'
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: note: when computing vector element at index '0'
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: note: when computing vector element at index '0'
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: note: when computing vector element at index '0'
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: note: when computing vector element at index '1'
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: note: when computing vector element at index '1'
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: note: when computing vector element at index '1'
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: note: when computing vector element at index '1'
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: note: when computing vector element at index '0'
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: note: when computing vector element at index '0'
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: note: when computing vector element at index '0'
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: note: when computing vector element at index '0'
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: note: when computing vector element at index '1'
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: note: when computing vector element at index '1'
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: note: when computing vector element at index '1'
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: note: when computing vector element at index '1'
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: note: when computing vector element at index '0'
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: note: when computing vector element at index '0'
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: note: when computing vector element at index '0'
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: note: when computing vector element at index '0'
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: note: when computing vector element at index '1'
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: note: when computing vector element at index '1'
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: note: when computing vector element at index '1'
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: note: when computing vector element at index '1'
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: note: when computing vector element at index '0'
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: note: when computing vector element at index '0'
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: note: when computing vector element at index '0'
// :167:25: error: use of undefined value here causes illegal behavior
// :167:25: note: when computing vector element at index '0'
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: note: when computing vector element at index '1'
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: note: when computing vector element at index '1'
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: note: when computing vector element at index '1'
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: note: when computing vector element at index '1'
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: note: when computing vector element at index '0'
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: note: when computing vector element at index '0'
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: note: when computing vector element at index '0'
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: note: when computing vector element at index '0'
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: note: when computing vector element at index '1'
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: note: when computing vector element at index '1'
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: note: when computing vector element at index '1'
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: note: when computing vector element at index '1'
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: note: when computing vector element at index '0'
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: note: when computing vector element at index '0'
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: note: when computing vector element at index '0'
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: note: when computing vector element at index '0'
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: note: when computing vector element at index '1'
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: note: when computing vector element at index '1'
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: note: when computing vector element at index '1'
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: note: when computing vector element at index '1'
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: note: when computing vector element at index '0'
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: note: when computing vector element at index '0'
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: note: when computing vector element at index '0'
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: note: when computing vector element at index '0'
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: note: when computing vector element at index '1'
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: note: when computing vector element at index '1'
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: note: when computing vector element at index '1'
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: note: when computing vector element at index '1'
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: note: when computing vector element at index '0'
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: note: when computing vector element at index '0'
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: note: when computing vector element at index '0'
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: note: when computing vector element at index '0'
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: note: when computing vector element at index '1'
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: note: when computing vector element at index '1'
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: note: when computing vector element at index '1'
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: note: when computing vector element at index '1'
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: note: when computing vector element at index '0'
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: note: when computing vector element at index '0'
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: note: when computing vector element at index '0'
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: note: when computing vector element at index '0'
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: note: when computing vector element at index '1'
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: note: when computing vector element at index '1'
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: note: when computing vector element at index '1'
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: note: when computing vector element at index '1'
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: note: when computing vector element at index '0'
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: note: when computing vector element at index '0'
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: note: when computing vector element at index '0'
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: note: when computing vector element at index '0'
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: note: when computing vector element at index '1'
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: note: when computing vector element at index '1'
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: note: when computing vector element at index '1'
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: note: when computing vector element at index '1'
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: note: when computing vector element at index '0'
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: note: when computing vector element at index '0'
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: note: when computing vector element at index '0'
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: note: when computing vector element at index '0'
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: note: when computing vector element at index '1'
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: note: when computing vector element at index '1'
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: note: when computing vector element at index '1'
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: note: when computing vector element at index '1'
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: note: when computing vector element at index '0'
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: note: when computing vector element at index '0'
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: note: when computing vector element at index '0'
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: note: when computing vector element at index '0'
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: note: when computing vector element at index '1'
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: note: when computing vector element at index '1'
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: note: when computing vector element at index '1'
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: note: when computing vector element at index '1'
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: note: when computing vector element at index '0'
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: note: when computing vector element at index '0'
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: note: when computing vector element at index '0'
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: note: when computing vector element at index '0'
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: note: when computing vector element at index '1'
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: note: when computing vector element at index '1'
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: note: when computing vector element at index '1'
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: note: when computing vector element at index '1'
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: note: when computing vector element at index '0'
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: note: when computing vector element at index '0'
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: note: when computing vector element at index '0'
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: note: when computing vector element at index '0'
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: note: when computing vector element at index '1'
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: note: when computing vector element at index '1'
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: note: when computing vector element at index '1'
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: note: when computing vector element at index '1'
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: note: when computing vector element at index '0'
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: note: when computing vector element at index '0'
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: note: when computing vector element at index '0'
// :171:25: error: use of undefined value here causes illegal behavior
// :171:25: note: when computing vector element at index '0'
// :177:17: error: use of undefined value here causes illegal behavior
// :177:17: error: use of undefined value here causes illegal behavior
// :177:17: error: use of undefined value here causes illegal behavior
// :177:17: note: when computing vector element at index '0'
// :177:17: error: use of undefined value here causes illegal behavior
// :177:17: note: when computing vector element at index '0'
// :177:17: error: use of undefined value here causes illegal behavior
// :177:17: note: when computing vector element at index '0'
// :177:17: error: use of undefined value here causes illegal behavior
// :177:17: note: when computing vector element at index '0'
// :177:17: error: use of undefined value here causes illegal behavior
// :177:17: note: when computing vector element at index '1'
// :177:17: error: use of undefined value here causes illegal behavior
// :177:17: note: when computing vector element at index '1'
// :177:17: error: use of undefined value here causes illegal behavior
// :177:17: note: when computing vector element at index '0'
// :177:17: error: use of undefined value here causes illegal behavior
// :177:17: note: when computing vector element at index '0'
// :177:17: error: use of undefined value here causes illegal behavior
// :177:17: note: when computing vector element at index '0'
// :177:17: error: use of undefined value here causes illegal behavior
// :177:17: note: when computing vector element at index '0'
// :177:17: error: use of undefined value here causes illegal behavior
// :177:17: error: use of undefined value here causes illegal behavior
// :177:17: error: use of undefined value here causes illegal behavior
// :177:17: note: when computing vector element at index '0'
// :177:17: error: use of undefined value here causes illegal behavior
// :177:17: note: when computing vector element at index '0'
// :177:17: error: use of undefined value here causes illegal behavior
// :177:17: note: when computing vector element at index '0'
// :177:17: error: use of undefined value here causes illegal behavior
// :177:17: note: when computing vector element at index '0'
// :177:17: error: use of undefined value here causes illegal behavior
// :177:17: note: when computing vector element at index '1'
// :177:17: error: use of undefined value here causes illegal behavior
// :177:17: note: when computing vector element at index '1'
// :177:17: error: use of undefined value here causes illegal behavior
// :177:17: note: when computing vector element at index '0'
// :177:17: error: use of undefined value here causes illegal behavior
// :177:17: note: when computing vector element at index '0'
// :177:17: error: use of undefined value here causes illegal behavior
// :177:17: note: when computing vector element at index '0'
// :177:17: error: use of undefined value here causes illegal behavior
// :177:17: note: when computing vector element at index '0'
// :177:17: error: use of undefined value here causes illegal behavior
// :177:17: error: use of undefined value here causes illegal behavior
// :177:17: error: use of undefined value here causes illegal behavior
// :177:17: note: when computing vector element at index '0'
// :177:17: error: use of undefined value here causes illegal behavior
// :177:17: note: when computing vector element at index '0'
// :177:17: error: use of undefined value here causes illegal behavior
// :177:17: note: when computing vector element at index '0'
// :177:17: error: use of undefined value here causes illegal behavior
// :177:17: note: when computing vector element at index '0'
// :177:17: error: use of undefined value here causes illegal behavior
// :177:17: note: when computing vector element at index '1'
// :177:17: error: use of undefined value here causes illegal behavior
// :177:17: note: when computing vector element at index '1'
// :177:17: error: use of undefined value here causes illegal behavior
// :177:17: note: when computing vector element at index '0'
// :177:17: error: use of undefined value here causes illegal behavior
// :177:17: note: when computing vector element at index '0'
// :177:17: error: use of undefined value here causes illegal behavior
// :177:17: note: when computing vector element at index '0'
// :177:17: error: use of undefined value here causes illegal behavior
// :177:17: note: when computing vector element at index '0'
// :177:17: error: use of undefined value here causes illegal behavior
// :177:17: error: use of undefined value here causes illegal behavior
// :177:17: error: use of undefined value here causes illegal behavior
// :177:17: note: when computing vector element at index '0'
// :177:17: error: use of undefined value here causes illegal behavior
// :177:17: note: when computing vector element at index '0'
// :177:17: error: use of undefined value here causes illegal behavior
// :177:17: note: when computing vector element at index '0'
// :177:17: error: use of undefined value here causes illegal behavior
// :177:17: note: when computing vector element at index '0'
// :177:17: error: use of undefined value here causes illegal behavior
// :177:17: note: when computing vector element at index '1'
// :177:17: error: use of undefined value here causes illegal behavior
// :177:17: note: when computing vector element at index '1'
// :177:17: error: use of undefined value here causes illegal behavior
// :177:17: note: when computing vector element at index '0'
// :177:17: error: use of undefined value here causes illegal behavior
// :177:17: note: when computing vector element at index '0'
// :177:17: error: use of undefined value here causes illegal behavior
// :177:17: note: when computing vector element at index '0'
// :177:17: error: use of undefined value here causes illegal behavior
// :177:17: note: when computing vector element at index '0'
// :177:17: error: use of undefined value here causes illegal behavior
// :177:17: error: use of undefined value here causes illegal behavior
// :177:17: error: use of undefined value here causes illegal behavior
// :177:17: note: when computing vector element at index '0'
// :177:17: error: use of undefined value here causes illegal behavior
// :177:17: note: when computing vector element at index '0'
// :177:17: error: use of undefined value here causes illegal behavior
// :177:17: note: when computing vector element at index '0'
// :177:17: error: use of undefined value here causes illegal behavior
// :177:17: note: when computing vector element at index '0'
// :177:17: error: use of undefined value here causes illegal behavior
// :177:17: note: when computing vector element at index '1'
// :177:17: error: use of undefined value here causes illegal behavior
// :177:17: note: when computing vector element at index '1'
// :177:17: error: use of undefined value here causes illegal behavior
// :177:17: note: when computing vector element at index '0'
// :177:17: error: use of undefined value here causes illegal behavior
// :177:17: note: when computing vector element at index '0'
// :177:17: error: use of undefined value here causes illegal behavior
// :177:17: note: when computing vector element at index '0'
// :177:17: error: use of undefined value here causes illegal behavior
// :177:17: note: when computing vector element at index '0'
// :177:17: error: use of undefined value here causes illegal behavior
// :177:17: error: use of undefined value here causes illegal behavior
// :177:17: error: use of undefined value here causes illegal behavior
// :177:17: note: when computing vector element at index '0'
// :177:17: error: use of undefined value here causes illegal behavior
// :177:17: note: when computing vector element at index '0'
// :177:17: error: use of undefined value here causes illegal behavior
// :177:17: note: when computing vector element at index '0'
// :177:17: error: use of undefined value here causes illegal behavior
// :177:17: note: when computing vector element at index '0'
// :177:17: error: use of undefined value here causes illegal behavior
// :177:17: note: when computing vector element at index '1'
// :177:17: error: use of undefined value here causes illegal behavior
// :177:17: note: when computing vector element at index '1'
// :177:17: error: use of undefined value here causes illegal behavior
// :177:17: note: when computing vector element at index '0'
// :177:17: error: use of undefined value here causes illegal behavior
// :177:17: note: when computing vector element at index '0'
// :177:17: error: use of undefined value here causes illegal behavior
// :177:17: note: when computing vector element at index '0'
// :177:17: error: use of undefined value here causes illegal behavior
// :177:17: note: when computing vector element at index '0'
// :177:21: error: use of undefined value here causes illegal behavior
// :177:21: note: when computing vector element at index '0'
// :177:21: error: use of undefined value here causes illegal behavior
// :177:21: note: when computing vector element at index '0'
// :177:21: error: use of undefined value here causes illegal behavior
// :177:21: note: when computing vector element at index '0'
// :177:21: error: use of undefined value here causes illegal behavior
// :177:21: note: when computing vector element at index '0'
// :177:21: error: use of undefined value here causes illegal behavior
// :177:21: note: when computing vector element at index '0'
// :177:21: error: use of undefined value here causes illegal behavior
// :177:21: note: when computing vector element at index '0'
// :177:21: error: use of undefined value here causes illegal behavior
// :177:21: note: when computing vector element at index '0'
// :177:21: error: use of undefined value here causes illegal behavior
// :177:21: note: when computing vector element at index '0'
// :177:21: error: use of undefined value here causes illegal behavior
// :177:21: note: when computing vector element at index '0'
// :177:21: error: use of undefined value here causes illegal behavior
// :177:21: note: when computing vector element at index '0'
// :177:21: error: use of undefined value here causes illegal behavior
// :177:21: note: when computing vector element at index '0'
// :177:21: error: use of undefined value here causes illegal behavior
// :177:21: note: when computing vector element at index '0'
// :180:17: error: use of undefined value here causes illegal behavior
// :180:17: error: use of undefined value here causes illegal behavior
// :180:17: error: use of undefined value here causes illegal behavior
// :180:17: note: when computing vector element at index '0'
// :180:17: error: use of undefined value here causes illegal behavior
// :180:17: note: when computing vector element at index '0'
// :180:17: error: use of undefined value here causes illegal behavior
// :180:17: note: when computing vector element at index '0'
// :180:17: error: use of undefined value here causes illegal behavior
// :180:17: note: when computing vector element at index '0'
// :180:17: error: use of undefined value here causes illegal behavior
// :180:17: note: when computing vector element at index '1'
// :180:17: error: use of undefined value here causes illegal behavior
// :180:17: note: when computing vector element at index '1'
// :180:17: error: use of undefined value here causes illegal behavior
// :180:17: note: when computing vector element at index '0'
// :180:17: error: use of undefined value here causes illegal behavior
// :180:17: note: when computing vector element at index '0'
// :180:17: error: use of undefined value here causes illegal behavior
// :180:17: note: when computing vector element at index '0'
// :180:17: error: use of undefined value here causes illegal behavior
// :180:17: note: when computing vector element at index '0'
// :180:17: error: use of undefined value here causes illegal behavior
// :180:17: error: use of undefined value here causes illegal behavior
// :180:17: error: use of undefined value here causes illegal behavior
// :180:17: note: when computing vector element at index '0'
// :180:17: error: use of undefined value here causes illegal behavior
// :180:17: note: when computing vector element at index '0'
// :180:17: error: use of undefined value here causes illegal behavior
// :180:17: note: when computing vector element at index '0'
// :180:17: error: use of undefined value here causes illegal behavior
// :180:17: note: when computing vector element at index '0'
// :180:17: error: use of undefined value here causes illegal behavior
// :180:17: note: when computing vector element at index '1'
// :180:17: error: use of undefined value here causes illegal behavior
// :180:17: note: when computing vector element at index '1'
// :180:17: error: use of undefined value here causes illegal behavior
// :180:17: note: when computing vector element at index '0'
// :180:17: error: use of undefined value here causes illegal behavior
// :180:17: note: when computing vector element at index '0'
// :180:17: error: use of undefined value here causes illegal behavior
// :180:17: note: when computing vector element at index '0'
// :180:17: error: use of undefined value here causes illegal behavior
// :180:17: note: when computing vector element at index '0'
// :180:17: error: use of undefined value here causes illegal behavior
// :180:17: error: use of undefined value here causes illegal behavior
// :180:17: error: use of undefined value here causes illegal behavior
// :180:17: note: when computing vector element at index '0'
// :180:17: error: use of undefined value here causes illegal behavior
// :180:17: note: when computing vector element at index '0'
// :180:17: error: use of undefined value here causes illegal behavior
// :180:17: note: when computing vector element at index '0'
// :180:17: error: use of undefined value here causes illegal behavior
// :180:17: note: when computing vector element at index '0'
// :180:17: error: use of undefined value here causes illegal behavior
// :180:17: note: when computing vector element at index '1'
// :180:17: error: use of undefined value here causes illegal behavior
// :180:17: note: when computing vector element at index '1'
// :180:17: error: use of undefined value here causes illegal behavior
// :180:17: note: when computing vector element at index '0'
// :180:17: error: use of undefined value here causes illegal behavior
// :180:17: note: when computing vector element at index '0'
// :180:17: error: use of undefined value here causes illegal behavior
// :180:17: note: when computing vector element at index '0'
// :180:17: error: use of undefined value here causes illegal behavior
// :180:17: note: when computing vector element at index '0'
// :180:17: error: use of undefined value here causes illegal behavior
// :180:17: error: use of undefined value here causes illegal behavior
// :180:17: error: use of undefined value here causes illegal behavior
// :180:17: note: when computing vector element at index '0'
// :180:17: error: use of undefined value here causes illegal behavior
// :180:17: note: when computing vector element at index '0'
// :180:17: error: use of undefined value here causes illegal behavior
// :180:17: note: when computing vector element at index '0'
// :180:17: error: use of undefined value here causes illegal behavior
// :180:17: note: when computing vector element at index '0'
// :180:17: error: use of undefined value here causes illegal behavior
// :180:17: note: when computing vector element at index '1'
// :180:17: error: use of undefined value here causes illegal behavior
// :180:17: note: when computing vector element at index '1'
// :180:17: error: use of undefined value here causes illegal behavior
// :180:17: note: when computing vector element at index '0'
// :180:17: error: use of undefined value here causes illegal behavior
// :180:17: note: when computing vector element at index '0'
// :180:17: error: use of undefined value here causes illegal behavior
// :180:17: note: when computing vector element at index '0'
// :180:17: error: use of undefined value here causes illegal behavior
// :180:17: note: when computing vector element at index '0'
// :180:17: error: use of undefined value here causes illegal behavior
// :180:17: error: use of undefined value here causes illegal behavior
// :180:17: error: use of undefined value here causes illegal behavior
// :180:17: note: when computing vector element at index '0'
// :180:17: error: use of undefined value here causes illegal behavior
// :180:17: note: when computing vector element at index '0'
// :180:17: error: use of undefined value here causes illegal behavior
// :180:17: note: when computing vector element at index '0'
// :180:17: error: use of undefined value here causes illegal behavior
// :180:17: note: when computing vector element at index '0'
// :180:17: error: use of undefined value here causes illegal behavior
// :180:17: note: when computing vector element at index '1'
// :180:17: error: use of undefined value here causes illegal behavior
// :180:17: note: when computing vector element at index '1'
// :180:17: error: use of undefined value here causes illegal behavior
// :180:17: note: when computing vector element at index '0'
// :180:17: error: use of undefined value here causes illegal behavior
// :180:17: note: when computing vector element at index '0'
// :180:17: error: use of undefined value here causes illegal behavior
// :180:17: note: when computing vector element at index '0'
// :180:17: error: use of undefined value here causes illegal behavior
// :180:17: note: when computing vector element at index '0'
// :180:17: error: use of undefined value here causes illegal behavior
// :180:17: error: use of undefined value here causes illegal behavior
// :180:17: error: use of undefined value here causes illegal behavior
// :180:17: note: when computing vector element at index '0'
// :180:17: error: use of undefined value here causes illegal behavior
// :180:17: note: when computing vector element at index '0'
// :180:17: error: use of undefined value here causes illegal behavior
// :180:17: note: when computing vector element at index '0'
// :180:17: error: use of undefined value here causes illegal behavior
// :180:17: note: when computing vector element at index '0'
// :180:17: error: use of undefined value here causes illegal behavior
// :180:17: note: when computing vector element at index '1'
// :180:17: error: use of undefined value here causes illegal behavior
// :180:17: note: when computing vector element at index '1'
// :180:17: error: use of undefined value here causes illegal behavior
// :180:17: note: when computing vector element at index '0'
// :180:17: error: use of undefined value here causes illegal behavior
// :180:17: note: when computing vector element at index '0'
// :180:17: error: use of undefined value here causes illegal behavior
// :180:17: note: when computing vector element at index '0'
// :180:17: error: use of undefined value here causes illegal behavior
// :180:17: note: when computing vector element at index '0'
// :180:21: error: use of undefined value here causes illegal behavior
// :180:21: note: when computing vector element at index '0'
// :180:21: error: use of undefined value here causes illegal behavior
// :180:21: note: when computing vector element at index '0'
// :180:21: error: use of undefined value here causes illegal behavior
// :180:21: note: when computing vector element at index '0'
// :180:21: error: use of undefined value here causes illegal behavior
// :180:21: note: when computing vector element at index '0'
// :180:21: error: use of undefined value here causes illegal behavior
// :180:21: note: when computing vector element at index '0'
// :180:21: error: use of undefined value here causes illegal behavior
// :180:21: note: when computing vector element at index '0'
// :180:21: error: use of undefined value here causes illegal behavior
// :180:21: note: when computing vector element at index '0'
// :180:21: error: use of undefined value here causes illegal behavior
// :180:21: note: when computing vector element at index '0'
// :180:21: error: use of undefined value here causes illegal behavior
// :180:21: note: when computing vector element at index '0'
// :180:21: error: use of undefined value here causes illegal behavior
// :180:21: note: when computing vector element at index '0'
// :180:21: error: use of undefined value here causes illegal behavior
// :180:21: note: when computing vector element at index '0'
// :180:21: error: use of undefined value here causes illegal behavior
// :180:21: note: when computing vector element at index '0'
// :183:17: error: use of undefined value here causes illegal behavior
// :183:17: error: use of undefined value here causes illegal behavior
// :183:17: error: use of undefined value here causes illegal behavior
// :183:17: note: when computing vector element at index '0'
// :183:17: error: use of undefined value here causes illegal behavior
// :183:17: note: when computing vector element at index '0'
// :183:17: error: use of undefined value here causes illegal behavior
// :183:17: note: when computing vector element at index '0'
// :183:17: error: use of undefined value here causes illegal behavior
// :183:17: note: when computing vector element at index '0'
// :183:17: error: use of undefined value here causes illegal behavior
// :183:17: note: when computing vector element at index '1'
// :183:17: error: use of undefined value here causes illegal behavior
// :183:17: note: when computing vector element at index '1'
// :183:17: error: use of undefined value here causes illegal behavior
// :183:17: note: when computing vector element at index '0'
// :183:17: error: use of undefined value here causes illegal behavior
// :183:17: note: when computing vector element at index '0'
// :183:17: error: use of undefined value here causes illegal behavior
// :183:17: note: when computing vector element at index '0'
// :183:17: error: use of undefined value here causes illegal behavior
// :183:17: note: when computing vector element at index '0'
// :183:17: error: use of undefined value here causes illegal behavior
// :183:17: error: use of undefined value here causes illegal behavior
// :183:17: error: use of undefined value here causes illegal behavior
// :183:17: note: when computing vector element at index '0'
// :183:17: error: use of undefined value here causes illegal behavior
// :183:17: note: when computing vector element at index '0'
// :183:17: error: use of undefined value here causes illegal behavior
// :183:17: note: when computing vector element at index '0'
// :183:17: error: use of undefined value here causes illegal behavior
// :183:17: note: when computing vector element at index '0'
// :183:17: error: use of undefined value here causes illegal behavior
// :183:17: note: when computing vector element at index '1'
// :183:17: error: use of undefined value here causes illegal behavior
// :183:17: note: when computing vector element at index '1'
// :183:17: error: use of undefined value here causes illegal behavior
// :183:17: note: when computing vector element at index '0'
// :183:17: error: use of undefined value here causes illegal behavior
// :183:17: note: when computing vector element at index '0'
// :183:17: error: use of undefined value here causes illegal behavior
// :183:17: note: when computing vector element at index '0'
// :183:17: error: use of undefined value here causes illegal behavior
// :183:17: note: when computing vector element at index '0'
// :183:17: error: use of undefined value here causes illegal behavior
// :183:17: error: use of undefined value here causes illegal behavior
// :183:17: error: use of undefined value here causes illegal behavior
// :183:17: note: when computing vector element at index '0'
// :183:17: error: use of undefined value here causes illegal behavior
// :183:17: note: when computing vector element at index '0'
// :183:17: error: use of undefined value here causes illegal behavior
// :183:17: note: when computing vector element at index '0'
// :183:17: error: use of undefined value here causes illegal behavior
// :183:17: note: when computing vector element at index '0'
// :183:17: error: use of undefined value here causes illegal behavior
// :183:17: note: when computing vector element at index '1'
// :183:17: error: use of undefined value here causes illegal behavior
// :183:17: note: when computing vector element at index '1'
// :183:17: error: use of undefined value here causes illegal behavior
// :183:17: note: when computing vector element at index '0'
// :183:17: error: use of undefined value here causes illegal behavior
// :183:17: note: when computing vector element at index '0'
// :183:17: error: use of undefined value here causes illegal behavior
// :183:17: note: when computing vector element at index '0'
// :183:17: error: use of undefined value here causes illegal behavior
// :183:17: note: when computing vector element at index '0'
// :183:17: error: use of undefined value here causes illegal behavior
// :183:17: error: use of undefined value here causes illegal behavior
// :183:17: error: use of undefined value here causes illegal behavior
// :183:17: note: when computing vector element at index '0'
// :183:17: error: use of undefined value here causes illegal behavior
// :183:17: note: when computing vector element at index '0'
// :183:17: error: use of undefined value here causes illegal behavior
// :183:17: note: when computing vector element at index '0'
// :183:17: error: use of undefined value here causes illegal behavior
// :183:17: note: when computing vector element at index '0'
// :183:17: error: use of undefined value here causes illegal behavior
// :183:17: note: when computing vector element at index '1'
// :183:17: error: use of undefined value here causes illegal behavior
// :183:17: note: when computing vector element at index '1'
// :183:17: error: use of undefined value here causes illegal behavior
// :183:17: note: when computing vector element at index '0'
// :183:17: error: use of undefined value here causes illegal behavior
// :183:17: note: when computing vector element at index '0'
// :183:17: error: use of undefined value here causes illegal behavior
// :183:17: note: when computing vector element at index '0'
// :183:17: error: use of undefined value here causes illegal behavior
// :183:17: note: when computing vector element at index '0'
// :183:17: error: use of undefined value here causes illegal behavior
// :183:17: error: use of undefined value here causes illegal behavior
// :183:17: error: use of undefined value here causes illegal behavior
// :183:17: note: when computing vector element at index '0'
// :183:17: error: use of undefined value here causes illegal behavior
// :183:17: note: when computing vector element at index '0'
// :183:17: error: use of undefined value here causes illegal behavior
// :183:17: note: when computing vector element at index '0'
// :183:17: error: use of undefined value here causes illegal behavior
// :183:17: note: when computing vector element at index '0'
// :183:17: error: use of undefined value here causes illegal behavior
// :183:17: note: when computing vector element at index '1'
// :183:17: error: use of undefined value here causes illegal behavior
// :183:17: note: when computing vector element at index '1'
// :183:17: error: use of undefined value here causes illegal behavior
// :183:17: note: when computing vector element at index '0'
// :183:17: error: use of undefined value here causes illegal behavior
// :183:17: note: when computing vector element at index '0'
// :183:17: error: use of undefined value here causes illegal behavior
// :183:17: note: when computing vector element at index '0'
// :183:17: error: use of undefined value here causes illegal behavior
// :183:17: note: when computing vector element at index '0'
// :183:17: error: use of undefined value here causes illegal behavior
// :183:17: error: use of undefined value here causes illegal behavior
// :183:17: error: use of undefined value here causes illegal behavior
// :183:17: note: when computing vector element at index '0'
// :183:17: error: use of undefined value here causes illegal behavior
// :183:17: note: when computing vector element at index '0'
// :183:17: error: use of undefined value here causes illegal behavior
// :183:17: note: when computing vector element at index '0'
// :183:17: error: use of undefined value here causes illegal behavior
// :183:17: note: when computing vector element at index '0'
// :183:17: error: use of undefined value here causes illegal behavior
// :183:17: note: when computing vector element at index '1'
// :183:17: error: use of undefined value here causes illegal behavior
// :183:17: note: when computing vector element at index '1'
// :183:17: error: use of undefined value here causes illegal behavior
// :183:17: note: when computing vector element at index '0'
// :183:17: error: use of undefined value here causes illegal behavior
// :183:17: note: when computing vector element at index '0'
// :183:17: error: use of undefined value here causes illegal behavior
// :183:17: note: when computing vector element at index '0'
// :183:17: error: use of undefined value here causes illegal behavior
// :183:17: note: when computing vector element at index '0'
// :183:21: error: use of undefined value here causes illegal behavior
// :183:21: note: when computing vector element at index '0'
// :183:21: error: use of undefined value here causes illegal behavior
// :183:21: note: when computing vector element at index '0'
// :183:21: error: use of undefined value here causes illegal behavior
// :183:21: note: when computing vector element at index '0'
// :183:21: error: use of undefined value here causes illegal behavior
// :183:21: note: when computing vector element at index '0'
// :183:21: error: use of undefined value here causes illegal behavior
// :183:21: note: when computing vector element at index '0'
// :183:21: error: use of undefined value here causes illegal behavior
// :183:21: note: when computing vector element at index '0'
// :183:21: error: use of undefined value here causes illegal behavior
// :183:21: note: when computing vector element at index '0'
// :183:21: error: use of undefined value here causes illegal behavior
// :183:21: note: when computing vector element at index '0'
// :183:21: error: use of undefined value here causes illegal behavior
// :183:21: note: when computing vector element at index '0'
// :183:21: error: use of undefined value here causes illegal behavior
// :183:21: note: when computing vector element at index '0'
// :183:21: error: use of undefined value here causes illegal behavior
// :183:21: note: when computing vector element at index '0'
// :183:21: error: use of undefined value here causes illegal behavior
// :183:21: note: when computing vector element at index '0'

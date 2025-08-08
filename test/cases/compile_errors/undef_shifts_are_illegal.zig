//! For shift operations which can trigger Illegal Behavior, this test evaluates those
//! operations with undefined operands (or partially-undefined vector operands), and ensures that a
//! compile error is emitted as expected.

comptime {
    // Total expected errors:
    // 20*14*6 = 1680

    testType(u8);
    testType(i8);
    testType(u32);
    testType(i32);
    testType(u500);
    testType(i500);
}

fn testType(comptime Scalar: type) void {
    // zig fmt: off
    testInner(Scalar,             undefined,                 0                        );
    testInner(Scalar,             undefined,                 undefined                );
    testInner(@Vector(2, Scalar), .{ undefined, undefined }, .{ undefined, undefined });
    testInner(@Vector(2, Scalar), .{ undefined, undefined }, .{ 0,         0         });
    testInner(@Vector(2, Scalar), .{ undefined, undefined }, .{ 0,         undefined });
    testInner(@Vector(2, Scalar), .{ undefined, undefined }, .{ undefined, 0         });
    testInner(@Vector(2, Scalar), .{ 0,         undefined }, .{ undefined, undefined });
    testInner(@Vector(2, Scalar), .{ 0,         undefined }, .{ 0,         0         });
    testInner(@Vector(2, Scalar), .{ 0,         undefined }, .{ 0,         undefined });
    testInner(@Vector(2, Scalar), .{ 0,         undefined }, .{ undefined, 0         });
    testInner(@Vector(2, Scalar), .{ undefined, 0         }, .{ undefined, undefined });
    testInner(@Vector(2, Scalar), .{ undefined, 0         }, .{ 0,         0         });
    testInner(@Vector(2, Scalar), .{ undefined, 0         }, .{ 0,         undefined });
    testInner(@Vector(2, Scalar), .{ undefined, 0         }, .{ undefined, 0         });
    // zig fmt: on
}

fn Log2T(comptime T: type) type {
    return switch (@typeInfo(T)) {
        .int => std.math.Log2Int(T),
        .vector => |v| @Vector(v.len, std.math.Log2Int(v.child)),
        else => unreachable,
    };
}

/// At the time of writing, this is expected to trigger:
/// * 20 errors if `T` is an int (or vector of ints)
fn testInner(comptime T: type, comptime u: T, comptime maybe_defined: Log2T(T)) void {
    _ = struct {
        const a: Log2T(T) = maybe_defined;
        var b: Log2T(T) = maybe_defined;

        // undef LHS, comptime-known RHS
        comptime {
            _ = u << a;
        }
        comptime {
            _ = @shlExact(u, a);
        }
        comptime {
            _ = @shlWithOverflow(u, a);
        }
        comptime {
            _ = u >> a;
        }
        comptime {
            _ = @shrExact(u, a);
        }

        // undef LHS, runtime-known RHS
        comptime {
            _ = u << b;
        }
        comptime {
            _ = @shlExact(u, b);
        }
        comptime {
            _ = @shlWithOverflow(u, b);
        }
        comptime {
            _ = u >> @truncate(b);
        }
        comptime {
            _ = @shrExact(u, b);
        }

        // undef RHS, comptime-known LHS
        comptime {
            _ = a << u;
        }
        comptime {
            _ = @shlExact(a, u);
        }
        comptime {
            _ = @shlWithOverflow(a, u);
        }
        comptime {
            _ = a >> u;
        }
        comptime {
            _ = @shrExact(a, u);
        }

        // undef RHS, runtime-known LHS
        comptime {
            _ = b << u;
        }
        comptime {
            _ = @shlExact(b, u);
        }
        comptime {
            _ = @shlWithOverflow(b, u);
        }
        comptime {
            _ = b >> u;
        }
        comptime {
            _ = @shrExact(b, u);
        }
    };
}

const std = @import("std");

// error
//
// :53:17: error: use of undefined value here causes illegal behavior
// :53:17: error: use of undefined value here causes illegal behavior
// :53:17: error: use of undefined value here causes illegal behavior
// :53:17: note: when computing vector element at index '0'
// :53:17: error: use of undefined value here causes illegal behavior
// :53:17: note: when computing vector element at index '0'
// :53:17: error: use of undefined value here causes illegal behavior
// :53:17: note: when computing vector element at index '0'
// :53:17: error: use of undefined value here causes illegal behavior
// :53:17: note: when computing vector element at index '0'
// :53:17: error: use of undefined value here causes illegal behavior
// :53:17: note: when computing vector element at index '1'
// :53:17: error: use of undefined value here causes illegal behavior
// :53:17: note: when computing vector element at index '1'
// :53:17: error: use of undefined value here causes illegal behavior
// :53:17: note: when computing vector element at index '0'
// :53:17: error: use of undefined value here causes illegal behavior
// :53:17: note: when computing vector element at index '0'
// :53:17: error: use of undefined value here causes illegal behavior
// :53:17: note: when computing vector element at index '0'
// :53:17: error: use of undefined value here causes illegal behavior
// :53:17: note: when computing vector element at index '0'
// :53:17: error: use of undefined value here causes illegal behavior
// :53:17: error: use of undefined value here causes illegal behavior
// :53:17: error: use of undefined value here causes illegal behavior
// :53:17: note: when computing vector element at index '0'
// :53:17: error: use of undefined value here causes illegal behavior
// :53:17: note: when computing vector element at index '0'
// :53:17: error: use of undefined value here causes illegal behavior
// :53:17: note: when computing vector element at index '0'
// :53:17: error: use of undefined value here causes illegal behavior
// :53:17: note: when computing vector element at index '0'
// :53:17: error: use of undefined value here causes illegal behavior
// :53:17: note: when computing vector element at index '1'
// :53:17: error: use of undefined value here causes illegal behavior
// :53:17: note: when computing vector element at index '1'
// :53:17: error: use of undefined value here causes illegal behavior
// :53:17: note: when computing vector element at index '0'
// :53:17: error: use of undefined value here causes illegal behavior
// :53:17: note: when computing vector element at index '0'
// :53:17: error: use of undefined value here causes illegal behavior
// :53:17: note: when computing vector element at index '0'
// :53:17: error: use of undefined value here causes illegal behavior
// :53:17: note: when computing vector element at index '0'
// :53:17: error: use of undefined value here causes illegal behavior
// :53:17: error: use of undefined value here causes illegal behavior
// :53:17: error: use of undefined value here causes illegal behavior
// :53:17: note: when computing vector element at index '0'
// :53:17: error: use of undefined value here causes illegal behavior
// :53:17: note: when computing vector element at index '0'
// :53:17: error: use of undefined value here causes illegal behavior
// :53:17: note: when computing vector element at index '0'
// :53:17: error: use of undefined value here causes illegal behavior
// :53:17: note: when computing vector element at index '0'
// :53:17: error: use of undefined value here causes illegal behavior
// :53:17: note: when computing vector element at index '1'
// :53:17: error: use of undefined value here causes illegal behavior
// :53:17: note: when computing vector element at index '1'
// :53:17: error: use of undefined value here causes illegal behavior
// :53:17: note: when computing vector element at index '0'
// :53:17: error: use of undefined value here causes illegal behavior
// :53:17: note: when computing vector element at index '0'
// :53:17: error: use of undefined value here causes illegal behavior
// :53:17: note: when computing vector element at index '0'
// :53:17: error: use of undefined value here causes illegal behavior
// :53:17: note: when computing vector element at index '0'
// :53:17: error: use of undefined value here causes illegal behavior
// :53:17: error: use of undefined value here causes illegal behavior
// :53:17: error: use of undefined value here causes illegal behavior
// :53:17: note: when computing vector element at index '0'
// :53:17: error: use of undefined value here causes illegal behavior
// :53:17: note: when computing vector element at index '0'
// :53:17: error: use of undefined value here causes illegal behavior
// :53:17: note: when computing vector element at index '0'
// :53:17: error: use of undefined value here causes illegal behavior
// :53:17: note: when computing vector element at index '0'
// :53:17: error: use of undefined value here causes illegal behavior
// :53:17: note: when computing vector element at index '1'
// :53:17: error: use of undefined value here causes illegal behavior
// :53:17: note: when computing vector element at index '1'
// :53:17: error: use of undefined value here causes illegal behavior
// :53:17: note: when computing vector element at index '0'
// :53:17: error: use of undefined value here causes illegal behavior
// :53:17: note: when computing vector element at index '0'
// :53:17: error: use of undefined value here causes illegal behavior
// :53:17: note: when computing vector element at index '0'
// :53:17: error: use of undefined value here causes illegal behavior
// :53:17: note: when computing vector element at index '0'
// :53:17: error: use of undefined value here causes illegal behavior
// :53:17: error: use of undefined value here causes illegal behavior
// :53:17: error: use of undefined value here causes illegal behavior
// :53:17: note: when computing vector element at index '0'
// :53:17: error: use of undefined value here causes illegal behavior
// :53:17: note: when computing vector element at index '0'
// :53:17: error: use of undefined value here causes illegal behavior
// :53:17: note: when computing vector element at index '0'
// :53:17: error: use of undefined value here causes illegal behavior
// :53:17: note: when computing vector element at index '0'
// :53:17: error: use of undefined value here causes illegal behavior
// :53:17: note: when computing vector element at index '1'
// :53:17: error: use of undefined value here causes illegal behavior
// :53:17: note: when computing vector element at index '1'
// :53:17: error: use of undefined value here causes illegal behavior
// :53:17: note: when computing vector element at index '0'
// :53:17: error: use of undefined value here causes illegal behavior
// :53:17: note: when computing vector element at index '0'
// :53:17: error: use of undefined value here causes illegal behavior
// :53:17: note: when computing vector element at index '0'
// :53:17: error: use of undefined value here causes illegal behavior
// :53:17: note: when computing vector element at index '0'
// :53:17: error: use of undefined value here causes illegal behavior
// :53:17: error: use of undefined value here causes illegal behavior
// :53:17: error: use of undefined value here causes illegal behavior
// :53:17: note: when computing vector element at index '0'
// :53:17: error: use of undefined value here causes illegal behavior
// :53:17: note: when computing vector element at index '0'
// :53:17: error: use of undefined value here causes illegal behavior
// :53:17: note: when computing vector element at index '0'
// :53:17: error: use of undefined value here causes illegal behavior
// :53:17: note: when computing vector element at index '0'
// :53:17: error: use of undefined value here causes illegal behavior
// :53:17: note: when computing vector element at index '1'
// :53:17: error: use of undefined value here causes illegal behavior
// :53:17: note: when computing vector element at index '1'
// :53:17: error: use of undefined value here causes illegal behavior
// :53:17: note: when computing vector element at index '0'
// :53:17: error: use of undefined value here causes illegal behavior
// :53:17: note: when computing vector element at index '0'
// :53:17: error: use of undefined value here causes illegal behavior
// :53:17: note: when computing vector element at index '0'
// :53:17: error: use of undefined value here causes illegal behavior
// :53:17: note: when computing vector element at index '0'
// :53:22: error: use of undefined value here causes illegal behavior
// :53:22: note: when computing vector element at index '0'
// :53:22: error: use of undefined value here causes illegal behavior
// :53:22: note: when computing vector element at index '0'
// :53:22: error: use of undefined value here causes illegal behavior
// :53:22: note: when computing vector element at index '0'
// :53:22: error: use of undefined value here causes illegal behavior
// :53:22: note: when computing vector element at index '0'
// :53:22: error: use of undefined value here causes illegal behavior
// :53:22: note: when computing vector element at index '0'
// :53:22: error: use of undefined value here causes illegal behavior
// :53:22: note: when computing vector element at index '0'
// :53:22: error: use of undefined value here causes illegal behavior
// :53:22: note: when computing vector element at index '0'
// :53:22: error: use of undefined value here causes illegal behavior
// :53:22: note: when computing vector element at index '0'
// :53:22: error: use of undefined value here causes illegal behavior
// :53:22: note: when computing vector element at index '0'
// :53:22: error: use of undefined value here causes illegal behavior
// :53:22: note: when computing vector element at index '0'
// :53:22: error: use of undefined value here causes illegal behavior
// :53:22: note: when computing vector element at index '0'
// :53:22: error: use of undefined value here causes illegal behavior
// :53:22: note: when computing vector element at index '0'
// :56:27: error: use of undefined value here causes illegal behavior
// :56:27: error: use of undefined value here causes illegal behavior
// :56:27: error: use of undefined value here causes illegal behavior
// :56:27: note: when computing vector element at index '0'
// :56:27: error: use of undefined value here causes illegal behavior
// :56:27: note: when computing vector element at index '0'
// :56:27: error: use of undefined value here causes illegal behavior
// :56:27: note: when computing vector element at index '0'
// :56:27: error: use of undefined value here causes illegal behavior
// :56:27: note: when computing vector element at index '0'
// :56:27: error: use of undefined value here causes illegal behavior
// :56:27: note: when computing vector element at index '1'
// :56:27: error: use of undefined value here causes illegal behavior
// :56:27: note: when computing vector element at index '1'
// :56:27: error: use of undefined value here causes illegal behavior
// :56:27: note: when computing vector element at index '0'
// :56:27: error: use of undefined value here causes illegal behavior
// :56:27: note: when computing vector element at index '0'
// :56:27: error: use of undefined value here causes illegal behavior
// :56:27: note: when computing vector element at index '0'
// :56:27: error: use of undefined value here causes illegal behavior
// :56:27: note: when computing vector element at index '0'
// :56:27: error: use of undefined value here causes illegal behavior
// :56:27: error: use of undefined value here causes illegal behavior
// :56:27: error: use of undefined value here causes illegal behavior
// :56:27: note: when computing vector element at index '0'
// :56:27: error: use of undefined value here causes illegal behavior
// :56:27: note: when computing vector element at index '0'
// :56:27: error: use of undefined value here causes illegal behavior
// :56:27: note: when computing vector element at index '0'
// :56:27: error: use of undefined value here causes illegal behavior
// :56:27: note: when computing vector element at index '0'
// :56:27: error: use of undefined value here causes illegal behavior
// :56:27: note: when computing vector element at index '1'
// :56:27: error: use of undefined value here causes illegal behavior
// :56:27: note: when computing vector element at index '1'
// :56:27: error: use of undefined value here causes illegal behavior
// :56:27: note: when computing vector element at index '0'
// :56:27: error: use of undefined value here causes illegal behavior
// :56:27: note: when computing vector element at index '0'
// :56:27: error: use of undefined value here causes illegal behavior
// :56:27: note: when computing vector element at index '0'
// :56:27: error: use of undefined value here causes illegal behavior
// :56:27: note: when computing vector element at index '0'
// :56:27: error: use of undefined value here causes illegal behavior
// :56:27: error: use of undefined value here causes illegal behavior
// :56:27: error: use of undefined value here causes illegal behavior
// :56:27: note: when computing vector element at index '0'
// :56:27: error: use of undefined value here causes illegal behavior
// :56:27: note: when computing vector element at index '0'
// :56:27: error: use of undefined value here causes illegal behavior
// :56:27: note: when computing vector element at index '0'
// :56:27: error: use of undefined value here causes illegal behavior
// :56:27: note: when computing vector element at index '0'
// :56:27: error: use of undefined value here causes illegal behavior
// :56:27: note: when computing vector element at index '1'
// :56:27: error: use of undefined value here causes illegal behavior
// :56:27: note: when computing vector element at index '1'
// :56:27: error: use of undefined value here causes illegal behavior
// :56:27: note: when computing vector element at index '0'
// :56:27: error: use of undefined value here causes illegal behavior
// :56:27: note: when computing vector element at index '0'
// :56:27: error: use of undefined value here causes illegal behavior
// :56:27: note: when computing vector element at index '0'
// :56:27: error: use of undefined value here causes illegal behavior
// :56:27: note: when computing vector element at index '0'
// :56:27: error: use of undefined value here causes illegal behavior
// :56:27: error: use of undefined value here causes illegal behavior
// :56:27: error: use of undefined value here causes illegal behavior
// :56:27: note: when computing vector element at index '0'
// :56:27: error: use of undefined value here causes illegal behavior
// :56:27: note: when computing vector element at index '0'
// :56:27: error: use of undefined value here causes illegal behavior
// :56:27: note: when computing vector element at index '0'
// :56:27: error: use of undefined value here causes illegal behavior
// :56:27: note: when computing vector element at index '0'
// :56:27: error: use of undefined value here causes illegal behavior
// :56:27: note: when computing vector element at index '1'
// :56:27: error: use of undefined value here causes illegal behavior
// :56:27: note: when computing vector element at index '1'
// :56:27: error: use of undefined value here causes illegal behavior
// :56:27: note: when computing vector element at index '0'
// :56:27: error: use of undefined value here causes illegal behavior
// :56:27: note: when computing vector element at index '0'
// :56:27: error: use of undefined value here causes illegal behavior
// :56:27: note: when computing vector element at index '0'
// :56:27: error: use of undefined value here causes illegal behavior
// :56:27: note: when computing vector element at index '0'
// :56:27: error: use of undefined value here causes illegal behavior
// :56:27: error: use of undefined value here causes illegal behavior
// :56:27: error: use of undefined value here causes illegal behavior
// :56:27: note: when computing vector element at index '0'
// :56:27: error: use of undefined value here causes illegal behavior
// :56:27: note: when computing vector element at index '0'
// :56:27: error: use of undefined value here causes illegal behavior
// :56:27: note: when computing vector element at index '0'
// :56:27: error: use of undefined value here causes illegal behavior
// :56:27: note: when computing vector element at index '0'
// :56:27: error: use of undefined value here causes illegal behavior
// :56:27: note: when computing vector element at index '1'
// :56:27: error: use of undefined value here causes illegal behavior
// :56:27: note: when computing vector element at index '1'
// :56:27: error: use of undefined value here causes illegal behavior
// :56:27: note: when computing vector element at index '0'
// :56:27: error: use of undefined value here causes illegal behavior
// :56:27: note: when computing vector element at index '0'
// :56:27: error: use of undefined value here causes illegal behavior
// :56:27: note: when computing vector element at index '0'
// :56:27: error: use of undefined value here causes illegal behavior
// :56:27: note: when computing vector element at index '0'
// :56:27: error: use of undefined value here causes illegal behavior
// :56:27: error: use of undefined value here causes illegal behavior
// :56:27: error: use of undefined value here causes illegal behavior
// :56:27: note: when computing vector element at index '0'
// :56:27: error: use of undefined value here causes illegal behavior
// :56:27: note: when computing vector element at index '0'
// :56:27: error: use of undefined value here causes illegal behavior
// :56:27: note: when computing vector element at index '0'
// :56:27: error: use of undefined value here causes illegal behavior
// :56:27: note: when computing vector element at index '0'
// :56:27: error: use of undefined value here causes illegal behavior
// :56:27: note: when computing vector element at index '1'
// :56:27: error: use of undefined value here causes illegal behavior
// :56:27: note: when computing vector element at index '1'
// :56:27: error: use of undefined value here causes illegal behavior
// :56:27: note: when computing vector element at index '0'
// :56:27: error: use of undefined value here causes illegal behavior
// :56:27: note: when computing vector element at index '0'
// :56:27: error: use of undefined value here causes illegal behavior
// :56:27: note: when computing vector element at index '0'
// :56:27: error: use of undefined value here causes illegal behavior
// :56:27: note: when computing vector element at index '0'
// :56:30: error: use of undefined value here causes illegal behavior
// :56:30: note: when computing vector element at index '0'
// :56:30: error: use of undefined value here causes illegal behavior
// :56:30: note: when computing vector element at index '0'
// :56:30: error: use of undefined value here causes illegal behavior
// :56:30: note: when computing vector element at index '0'
// :56:30: error: use of undefined value here causes illegal behavior
// :56:30: note: when computing vector element at index '0'
// :56:30: error: use of undefined value here causes illegal behavior
// :56:30: note: when computing vector element at index '0'
// :56:30: error: use of undefined value here causes illegal behavior
// :56:30: note: when computing vector element at index '0'
// :56:30: error: use of undefined value here causes illegal behavior
// :56:30: note: when computing vector element at index '0'
// :56:30: error: use of undefined value here causes illegal behavior
// :56:30: note: when computing vector element at index '0'
// :56:30: error: use of undefined value here causes illegal behavior
// :56:30: note: when computing vector element at index '0'
// :56:30: error: use of undefined value here causes illegal behavior
// :56:30: note: when computing vector element at index '0'
// :56:30: error: use of undefined value here causes illegal behavior
// :56:30: note: when computing vector element at index '0'
// :56:30: error: use of undefined value here causes illegal behavior
// :56:30: note: when computing vector element at index '0'
// :59:34: error: use of undefined value here causes illegal behavior
// :59:34: error: use of undefined value here causes illegal behavior
// :59:34: error: use of undefined value here causes illegal behavior
// :59:34: note: when computing vector element at index '0'
// :59:34: error: use of undefined value here causes illegal behavior
// :59:34: note: when computing vector element at index '0'
// :59:34: error: use of undefined value here causes illegal behavior
// :59:34: note: when computing vector element at index '0'
// :59:34: error: use of undefined value here causes illegal behavior
// :59:34: note: when computing vector element at index '0'
// :59:34: error: use of undefined value here causes illegal behavior
// :59:34: note: when computing vector element at index '1'
// :59:34: error: use of undefined value here causes illegal behavior
// :59:34: note: when computing vector element at index '1'
// :59:34: error: use of undefined value here causes illegal behavior
// :59:34: note: when computing vector element at index '0'
// :59:34: error: use of undefined value here causes illegal behavior
// :59:34: note: when computing vector element at index '0'
// :59:34: error: use of undefined value here causes illegal behavior
// :59:34: note: when computing vector element at index '0'
// :59:34: error: use of undefined value here causes illegal behavior
// :59:34: note: when computing vector element at index '0'
// :59:34: error: use of undefined value here causes illegal behavior
// :59:34: error: use of undefined value here causes illegal behavior
// :59:34: error: use of undefined value here causes illegal behavior
// :59:34: note: when computing vector element at index '0'
// :59:34: error: use of undefined value here causes illegal behavior
// :59:34: note: when computing vector element at index '0'
// :59:34: error: use of undefined value here causes illegal behavior
// :59:34: note: when computing vector element at index '0'
// :59:34: error: use of undefined value here causes illegal behavior
// :59:34: note: when computing vector element at index '0'
// :59:34: error: use of undefined value here causes illegal behavior
// :59:34: note: when computing vector element at index '1'
// :59:34: error: use of undefined value here causes illegal behavior
// :59:34: note: when computing vector element at index '1'
// :59:34: error: use of undefined value here causes illegal behavior
// :59:34: note: when computing vector element at index '0'
// :59:34: error: use of undefined value here causes illegal behavior
// :59:34: note: when computing vector element at index '0'
// :59:34: error: use of undefined value here causes illegal behavior
// :59:34: note: when computing vector element at index '0'
// :59:34: error: use of undefined value here causes illegal behavior
// :59:34: note: when computing vector element at index '0'
// :59:34: error: use of undefined value here causes illegal behavior
// :59:34: error: use of undefined value here causes illegal behavior
// :59:34: error: use of undefined value here causes illegal behavior
// :59:34: note: when computing vector element at index '0'
// :59:34: error: use of undefined value here causes illegal behavior
// :59:34: note: when computing vector element at index '0'
// :59:34: error: use of undefined value here causes illegal behavior
// :59:34: note: when computing vector element at index '0'
// :59:34: error: use of undefined value here causes illegal behavior
// :59:34: note: when computing vector element at index '0'
// :59:34: error: use of undefined value here causes illegal behavior
// :59:34: note: when computing vector element at index '1'
// :59:34: error: use of undefined value here causes illegal behavior
// :59:34: note: when computing vector element at index '1'
// :59:34: error: use of undefined value here causes illegal behavior
// :59:34: note: when computing vector element at index '0'
// :59:34: error: use of undefined value here causes illegal behavior
// :59:34: note: when computing vector element at index '0'
// :59:34: error: use of undefined value here causes illegal behavior
// :59:34: note: when computing vector element at index '0'
// :59:34: error: use of undefined value here causes illegal behavior
// :59:34: note: when computing vector element at index '0'
// :59:34: error: use of undefined value here causes illegal behavior
// :59:34: error: use of undefined value here causes illegal behavior
// :59:34: error: use of undefined value here causes illegal behavior
// :59:34: note: when computing vector element at index '0'
// :59:34: error: use of undefined value here causes illegal behavior
// :59:34: note: when computing vector element at index '0'
// :59:34: error: use of undefined value here causes illegal behavior
// :59:34: note: when computing vector element at index '0'
// :59:34: error: use of undefined value here causes illegal behavior
// :59:34: note: when computing vector element at index '0'
// :59:34: error: use of undefined value here causes illegal behavior
// :59:34: note: when computing vector element at index '1'
// :59:34: error: use of undefined value here causes illegal behavior
// :59:34: note: when computing vector element at index '1'
// :59:34: error: use of undefined value here causes illegal behavior
// :59:34: note: when computing vector element at index '0'
// :59:34: error: use of undefined value here causes illegal behavior
// :59:34: note: when computing vector element at index '0'
// :59:34: error: use of undefined value here causes illegal behavior
// :59:34: note: when computing vector element at index '0'
// :59:34: error: use of undefined value here causes illegal behavior
// :59:34: note: when computing vector element at index '0'
// :59:34: error: use of undefined value here causes illegal behavior
// :59:34: error: use of undefined value here causes illegal behavior
// :59:34: error: use of undefined value here causes illegal behavior
// :59:34: note: when computing vector element at index '0'
// :59:34: error: use of undefined value here causes illegal behavior
// :59:34: note: when computing vector element at index '0'
// :59:34: error: use of undefined value here causes illegal behavior
// :59:34: note: when computing vector element at index '0'
// :59:34: error: use of undefined value here causes illegal behavior
// :59:34: note: when computing vector element at index '0'
// :59:34: error: use of undefined value here causes illegal behavior
// :59:34: note: when computing vector element at index '1'
// :59:34: error: use of undefined value here causes illegal behavior
// :59:34: note: when computing vector element at index '1'
// :59:34: error: use of undefined value here causes illegal behavior
// :59:34: note: when computing vector element at index '0'
// :59:34: error: use of undefined value here causes illegal behavior
// :59:34: note: when computing vector element at index '0'
// :59:34: error: use of undefined value here causes illegal behavior
// :59:34: note: when computing vector element at index '0'
// :59:34: error: use of undefined value here causes illegal behavior
// :59:34: note: when computing vector element at index '0'
// :59:34: error: use of undefined value here causes illegal behavior
// :59:34: error: use of undefined value here causes illegal behavior
// :59:34: error: use of undefined value here causes illegal behavior
// :59:34: note: when computing vector element at index '0'
// :59:34: error: use of undefined value here causes illegal behavior
// :59:34: note: when computing vector element at index '0'
// :59:34: error: use of undefined value here causes illegal behavior
// :59:34: note: when computing vector element at index '0'
// :59:34: error: use of undefined value here causes illegal behavior
// :59:34: note: when computing vector element at index '0'
// :59:34: error: use of undefined value here causes illegal behavior
// :59:34: note: when computing vector element at index '1'
// :59:34: error: use of undefined value here causes illegal behavior
// :59:34: note: when computing vector element at index '1'
// :59:34: error: use of undefined value here causes illegal behavior
// :59:34: note: when computing vector element at index '0'
// :59:34: error: use of undefined value here causes illegal behavior
// :59:34: note: when computing vector element at index '0'
// :59:34: error: use of undefined value here causes illegal behavior
// :59:34: note: when computing vector element at index '0'
// :59:34: error: use of undefined value here causes illegal behavior
// :59:34: note: when computing vector element at index '0'
// :59:37: error: use of undefined value here causes illegal behavior
// :59:37: note: when computing vector element at index '0'
// :59:37: error: use of undefined value here causes illegal behavior
// :59:37: note: when computing vector element at index '0'
// :59:37: error: use of undefined value here causes illegal behavior
// :59:37: note: when computing vector element at index '0'
// :59:37: error: use of undefined value here causes illegal behavior
// :59:37: note: when computing vector element at index '0'
// :59:37: error: use of undefined value here causes illegal behavior
// :59:37: note: when computing vector element at index '0'
// :59:37: error: use of undefined value here causes illegal behavior
// :59:37: note: when computing vector element at index '0'
// :59:37: error: use of undefined value here causes illegal behavior
// :59:37: note: when computing vector element at index '0'
// :59:37: error: use of undefined value here causes illegal behavior
// :59:37: note: when computing vector element at index '0'
// :59:37: error: use of undefined value here causes illegal behavior
// :59:37: note: when computing vector element at index '0'
// :59:37: error: use of undefined value here causes illegal behavior
// :59:37: note: when computing vector element at index '0'
// :59:37: error: use of undefined value here causes illegal behavior
// :59:37: note: when computing vector element at index '0'
// :59:37: error: use of undefined value here causes illegal behavior
// :59:37: note: when computing vector element at index '0'
// :62:17: error: use of undefined value here causes illegal behavior
// :62:17: error: use of undefined value here causes illegal behavior
// :62:17: error: use of undefined value here causes illegal behavior
// :62:17: note: when computing vector element at index '0'
// :62:17: error: use of undefined value here causes illegal behavior
// :62:17: note: when computing vector element at index '0'
// :62:17: error: use of undefined value here causes illegal behavior
// :62:17: note: when computing vector element at index '0'
// :62:17: error: use of undefined value here causes illegal behavior
// :62:17: note: when computing vector element at index '0'
// :62:17: error: use of undefined value here causes illegal behavior
// :62:17: note: when computing vector element at index '1'
// :62:17: error: use of undefined value here causes illegal behavior
// :62:17: note: when computing vector element at index '1'
// :62:17: error: use of undefined value here causes illegal behavior
// :62:17: note: when computing vector element at index '0'
// :62:17: error: use of undefined value here causes illegal behavior
// :62:17: note: when computing vector element at index '0'
// :62:17: error: use of undefined value here causes illegal behavior
// :62:17: note: when computing vector element at index '0'
// :62:17: error: use of undefined value here causes illegal behavior
// :62:17: note: when computing vector element at index '0'
// :62:17: error: use of undefined value here causes illegal behavior
// :62:17: error: use of undefined value here causes illegal behavior
// :62:17: error: use of undefined value here causes illegal behavior
// :62:17: note: when computing vector element at index '0'
// :62:17: error: use of undefined value here causes illegal behavior
// :62:17: note: when computing vector element at index '0'
// :62:17: error: use of undefined value here causes illegal behavior
// :62:17: note: when computing vector element at index '0'
// :62:17: error: use of undefined value here causes illegal behavior
// :62:17: note: when computing vector element at index '0'
// :62:17: error: use of undefined value here causes illegal behavior
// :62:17: note: when computing vector element at index '1'
// :62:17: error: use of undefined value here causes illegal behavior
// :62:17: note: when computing vector element at index '1'
// :62:17: error: use of undefined value here causes illegal behavior
// :62:17: note: when computing vector element at index '0'
// :62:17: error: use of undefined value here causes illegal behavior
// :62:17: note: when computing vector element at index '0'
// :62:17: error: use of undefined value here causes illegal behavior
// :62:17: note: when computing vector element at index '0'
// :62:17: error: use of undefined value here causes illegal behavior
// :62:17: note: when computing vector element at index '0'
// :62:17: error: use of undefined value here causes illegal behavior
// :62:17: error: use of undefined value here causes illegal behavior
// :62:17: error: use of undefined value here causes illegal behavior
// :62:17: note: when computing vector element at index '0'
// :62:17: error: use of undefined value here causes illegal behavior
// :62:17: note: when computing vector element at index '0'
// :62:17: error: use of undefined value here causes illegal behavior
// :62:17: note: when computing vector element at index '0'
// :62:17: error: use of undefined value here causes illegal behavior
// :62:17: note: when computing vector element at index '0'
// :62:17: error: use of undefined value here causes illegal behavior
// :62:17: note: when computing vector element at index '1'
// :62:17: error: use of undefined value here causes illegal behavior
// :62:17: note: when computing vector element at index '1'
// :62:17: error: use of undefined value here causes illegal behavior
// :62:17: note: when computing vector element at index '0'
// :62:17: error: use of undefined value here causes illegal behavior
// :62:17: note: when computing vector element at index '0'
// :62:17: error: use of undefined value here causes illegal behavior
// :62:17: note: when computing vector element at index '0'
// :62:17: error: use of undefined value here causes illegal behavior
// :62:17: note: when computing vector element at index '0'
// :62:17: error: use of undefined value here causes illegal behavior
// :62:17: error: use of undefined value here causes illegal behavior
// :62:17: error: use of undefined value here causes illegal behavior
// :62:17: note: when computing vector element at index '0'
// :62:17: error: use of undefined value here causes illegal behavior
// :62:17: note: when computing vector element at index '0'
// :62:17: error: use of undefined value here causes illegal behavior
// :62:17: note: when computing vector element at index '0'
// :62:17: error: use of undefined value here causes illegal behavior
// :62:17: note: when computing vector element at index '0'
// :62:17: error: use of undefined value here causes illegal behavior
// :62:17: note: when computing vector element at index '1'
// :62:17: error: use of undefined value here causes illegal behavior
// :62:17: note: when computing vector element at index '1'
// :62:17: error: use of undefined value here causes illegal behavior
// :62:17: note: when computing vector element at index '0'
// :62:17: error: use of undefined value here causes illegal behavior
// :62:17: note: when computing vector element at index '0'
// :62:17: error: use of undefined value here causes illegal behavior
// :62:17: note: when computing vector element at index '0'
// :62:17: error: use of undefined value here causes illegal behavior
// :62:17: note: when computing vector element at index '0'
// :62:17: error: use of undefined value here causes illegal behavior
// :62:17: error: use of undefined value here causes illegal behavior
// :62:17: error: use of undefined value here causes illegal behavior
// :62:17: note: when computing vector element at index '0'
// :62:17: error: use of undefined value here causes illegal behavior
// :62:17: note: when computing vector element at index '0'
// :62:17: error: use of undefined value here causes illegal behavior
// :62:17: note: when computing vector element at index '0'
// :62:17: error: use of undefined value here causes illegal behavior
// :62:17: note: when computing vector element at index '0'
// :62:17: error: use of undefined value here causes illegal behavior
// :62:17: note: when computing vector element at index '1'
// :62:17: error: use of undefined value here causes illegal behavior
// :62:17: note: when computing vector element at index '1'
// :62:17: error: use of undefined value here causes illegal behavior
// :62:17: note: when computing vector element at index '0'
// :62:17: error: use of undefined value here causes illegal behavior
// :62:17: note: when computing vector element at index '0'
// :62:17: error: use of undefined value here causes illegal behavior
// :62:17: note: when computing vector element at index '0'
// :62:17: error: use of undefined value here causes illegal behavior
// :62:17: note: when computing vector element at index '0'
// :62:17: error: use of undefined value here causes illegal behavior
// :62:17: error: use of undefined value here causes illegal behavior
// :62:17: error: use of undefined value here causes illegal behavior
// :62:17: note: when computing vector element at index '0'
// :62:17: error: use of undefined value here causes illegal behavior
// :62:17: note: when computing vector element at index '0'
// :62:17: error: use of undefined value here causes illegal behavior
// :62:17: note: when computing vector element at index '0'
// :62:17: error: use of undefined value here causes illegal behavior
// :62:17: note: when computing vector element at index '0'
// :62:17: error: use of undefined value here causes illegal behavior
// :62:17: note: when computing vector element at index '1'
// :62:17: error: use of undefined value here causes illegal behavior
// :62:17: note: when computing vector element at index '1'
// :62:17: error: use of undefined value here causes illegal behavior
// :62:17: note: when computing vector element at index '0'
// :62:17: error: use of undefined value here causes illegal behavior
// :62:17: note: when computing vector element at index '0'
// :62:17: error: use of undefined value here causes illegal behavior
// :62:17: note: when computing vector element at index '0'
// :62:17: error: use of undefined value here causes illegal behavior
// :62:17: note: when computing vector element at index '0'
// :62:22: error: use of undefined value here causes illegal behavior
// :62:22: note: when computing vector element at index '0'
// :62:22: error: use of undefined value here causes illegal behavior
// :62:22: note: when computing vector element at index '0'
// :62:22: error: use of undefined value here causes illegal behavior
// :62:22: note: when computing vector element at index '0'
// :62:22: error: use of undefined value here causes illegal behavior
// :62:22: note: when computing vector element at index '0'
// :62:22: error: use of undefined value here causes illegal behavior
// :62:22: note: when computing vector element at index '0'
// :62:22: error: use of undefined value here causes illegal behavior
// :62:22: note: when computing vector element at index '0'
// :62:22: error: use of undefined value here causes illegal behavior
// :62:22: note: when computing vector element at index '0'
// :62:22: error: use of undefined value here causes illegal behavior
// :62:22: note: when computing vector element at index '0'
// :62:22: error: use of undefined value here causes illegal behavior
// :62:22: note: when computing vector element at index '0'
// :62:22: error: use of undefined value here causes illegal behavior
// :62:22: note: when computing vector element at index '0'
// :62:22: error: use of undefined value here causes illegal behavior
// :62:22: note: when computing vector element at index '0'
// :62:22: error: use of undefined value here causes illegal behavior
// :62:22: note: when computing vector element at index '0'
// :65:27: error: use of undefined value here causes illegal behavior
// :65:27: error: use of undefined value here causes illegal behavior
// :65:27: error: use of undefined value here causes illegal behavior
// :65:27: note: when computing vector element at index '0'
// :65:27: error: use of undefined value here causes illegal behavior
// :65:27: note: when computing vector element at index '0'
// :65:27: error: use of undefined value here causes illegal behavior
// :65:27: note: when computing vector element at index '0'
// :65:27: error: use of undefined value here causes illegal behavior
// :65:27: note: when computing vector element at index '0'
// :65:27: error: use of undefined value here causes illegal behavior
// :65:27: note: when computing vector element at index '1'
// :65:27: error: use of undefined value here causes illegal behavior
// :65:27: note: when computing vector element at index '1'
// :65:27: error: use of undefined value here causes illegal behavior
// :65:27: note: when computing vector element at index '0'
// :65:27: error: use of undefined value here causes illegal behavior
// :65:27: note: when computing vector element at index '0'
// :65:27: error: use of undefined value here causes illegal behavior
// :65:27: note: when computing vector element at index '0'
// :65:27: error: use of undefined value here causes illegal behavior
// :65:27: note: when computing vector element at index '0'
// :65:27: error: use of undefined value here causes illegal behavior
// :65:27: error: use of undefined value here causes illegal behavior
// :65:27: error: use of undefined value here causes illegal behavior
// :65:27: note: when computing vector element at index '0'
// :65:27: error: use of undefined value here causes illegal behavior
// :65:27: note: when computing vector element at index '0'
// :65:27: error: use of undefined value here causes illegal behavior
// :65:27: note: when computing vector element at index '0'
// :65:27: error: use of undefined value here causes illegal behavior
// :65:27: note: when computing vector element at index '0'
// :65:27: error: use of undefined value here causes illegal behavior
// :65:27: note: when computing vector element at index '1'
// :65:27: error: use of undefined value here causes illegal behavior
// :65:27: note: when computing vector element at index '1'
// :65:27: error: use of undefined value here causes illegal behavior
// :65:27: note: when computing vector element at index '0'
// :65:27: error: use of undefined value here causes illegal behavior
// :65:27: note: when computing vector element at index '0'
// :65:27: error: use of undefined value here causes illegal behavior
// :65:27: note: when computing vector element at index '0'
// :65:27: error: use of undefined value here causes illegal behavior
// :65:27: note: when computing vector element at index '0'
// :65:27: error: use of undefined value here causes illegal behavior
// :65:27: error: use of undefined value here causes illegal behavior
// :65:27: error: use of undefined value here causes illegal behavior
// :65:27: note: when computing vector element at index '0'
// :65:27: error: use of undefined value here causes illegal behavior
// :65:27: note: when computing vector element at index '0'
// :65:27: error: use of undefined value here causes illegal behavior
// :65:27: note: when computing vector element at index '0'
// :65:27: error: use of undefined value here causes illegal behavior
// :65:27: note: when computing vector element at index '0'
// :65:27: error: use of undefined value here causes illegal behavior
// :65:27: note: when computing vector element at index '1'
// :65:27: error: use of undefined value here causes illegal behavior
// :65:27: note: when computing vector element at index '1'
// :65:27: error: use of undefined value here causes illegal behavior
// :65:27: note: when computing vector element at index '0'
// :65:27: error: use of undefined value here causes illegal behavior
// :65:27: note: when computing vector element at index '0'
// :65:27: error: use of undefined value here causes illegal behavior
// :65:27: note: when computing vector element at index '0'
// :65:27: error: use of undefined value here causes illegal behavior
// :65:27: note: when computing vector element at index '0'
// :65:27: error: use of undefined value here causes illegal behavior
// :65:27: error: use of undefined value here causes illegal behavior
// :65:27: error: use of undefined value here causes illegal behavior
// :65:27: note: when computing vector element at index '0'
// :65:27: error: use of undefined value here causes illegal behavior
// :65:27: note: when computing vector element at index '0'
// :65:27: error: use of undefined value here causes illegal behavior
// :65:27: note: when computing vector element at index '0'
// :65:27: error: use of undefined value here causes illegal behavior
// :65:27: note: when computing vector element at index '0'
// :65:27: error: use of undefined value here causes illegal behavior
// :65:27: note: when computing vector element at index '1'
// :65:27: error: use of undefined value here causes illegal behavior
// :65:27: note: when computing vector element at index '1'
// :65:27: error: use of undefined value here causes illegal behavior
// :65:27: note: when computing vector element at index '0'
// :65:27: error: use of undefined value here causes illegal behavior
// :65:27: note: when computing vector element at index '0'
// :65:27: error: use of undefined value here causes illegal behavior
// :65:27: note: when computing vector element at index '0'
// :65:27: error: use of undefined value here causes illegal behavior
// :65:27: note: when computing vector element at index '0'
// :65:27: error: use of undefined value here causes illegal behavior
// :65:27: error: use of undefined value here causes illegal behavior
// :65:27: error: use of undefined value here causes illegal behavior
// :65:27: note: when computing vector element at index '0'
// :65:27: error: use of undefined value here causes illegal behavior
// :65:27: note: when computing vector element at index '0'
// :65:27: error: use of undefined value here causes illegal behavior
// :65:27: note: when computing vector element at index '0'
// :65:27: error: use of undefined value here causes illegal behavior
// :65:27: note: when computing vector element at index '0'
// :65:27: error: use of undefined value here causes illegal behavior
// :65:27: note: when computing vector element at index '1'
// :65:27: error: use of undefined value here causes illegal behavior
// :65:27: note: when computing vector element at index '1'
// :65:27: error: use of undefined value here causes illegal behavior
// :65:27: note: when computing vector element at index '0'
// :65:27: error: use of undefined value here causes illegal behavior
// :65:27: note: when computing vector element at index '0'
// :65:27: error: use of undefined value here causes illegal behavior
// :65:27: note: when computing vector element at index '0'
// :65:27: error: use of undefined value here causes illegal behavior
// :65:27: note: when computing vector element at index '0'
// :65:27: error: use of undefined value here causes illegal behavior
// :65:27: error: use of undefined value here causes illegal behavior
// :65:27: error: use of undefined value here causes illegal behavior
// :65:27: note: when computing vector element at index '0'
// :65:27: error: use of undefined value here causes illegal behavior
// :65:27: note: when computing vector element at index '0'
// :65:27: error: use of undefined value here causes illegal behavior
// :65:27: note: when computing vector element at index '0'
// :65:27: error: use of undefined value here causes illegal behavior
// :65:27: note: when computing vector element at index '0'
// :65:27: error: use of undefined value here causes illegal behavior
// :65:27: note: when computing vector element at index '1'
// :65:27: error: use of undefined value here causes illegal behavior
// :65:27: note: when computing vector element at index '1'
// :65:27: error: use of undefined value here causes illegal behavior
// :65:27: note: when computing vector element at index '0'
// :65:27: error: use of undefined value here causes illegal behavior
// :65:27: note: when computing vector element at index '0'
// :65:27: error: use of undefined value here causes illegal behavior
// :65:27: note: when computing vector element at index '0'
// :65:27: error: use of undefined value here causes illegal behavior
// :65:27: note: when computing vector element at index '0'
// :65:30: error: use of undefined value here causes illegal behavior
// :65:30: note: when computing vector element at index '0'
// :65:30: error: use of undefined value here causes illegal behavior
// :65:30: note: when computing vector element at index '0'
// :65:30: error: use of undefined value here causes illegal behavior
// :65:30: note: when computing vector element at index '0'
// :65:30: error: use of undefined value here causes illegal behavior
// :65:30: note: when computing vector element at index '0'
// :65:30: error: use of undefined value here causes illegal behavior
// :65:30: note: when computing vector element at index '0'
// :65:30: error: use of undefined value here causes illegal behavior
// :65:30: note: when computing vector element at index '0'
// :65:30: error: use of undefined value here causes illegal behavior
// :65:30: note: when computing vector element at index '0'
// :65:30: error: use of undefined value here causes illegal behavior
// :65:30: note: when computing vector element at index '0'
// :65:30: error: use of undefined value here causes illegal behavior
// :65:30: note: when computing vector element at index '0'
// :65:30: error: use of undefined value here causes illegal behavior
// :65:30: note: when computing vector element at index '0'
// :65:30: error: use of undefined value here causes illegal behavior
// :65:30: note: when computing vector element at index '0'
// :65:30: error: use of undefined value here causes illegal behavior
// :65:30: note: when computing vector element at index '0'
// :70:17: error: use of undefined value here causes illegal behavior
// :70:17: error: use of undefined value here causes illegal behavior
// :70:17: error: use of undefined value here causes illegal behavior
// :70:17: error: use of undefined value here causes illegal behavior
// :70:17: error: use of undefined value here causes illegal behavior
// :70:17: error: use of undefined value here causes illegal behavior
// :70:17: error: use of undefined value here causes illegal behavior
// :70:17: note: when computing vector element at index '1'
// :70:17: error: use of undefined value here causes illegal behavior
// :70:17: note: when computing vector element at index '1'
// :70:17: error: use of undefined value here causes illegal behavior
// :70:17: note: when computing vector element at index '1'
// :70:17: error: use of undefined value here causes illegal behavior
// :70:17: note: when computing vector element at index '1'
// :70:17: error: use of undefined value here causes illegal behavior
// :70:17: note: when computing vector element at index '0'
// :70:17: error: use of undefined value here causes illegal behavior
// :70:17: note: when computing vector element at index '0'
// :70:17: error: use of undefined value here causes illegal behavior
// :70:17: note: when computing vector element at index '0'
// :70:17: error: use of undefined value here causes illegal behavior
// :70:17: note: when computing vector element at index '0'
// :70:17: error: use of undefined value here causes illegal behavior
// :70:17: error: use of undefined value here causes illegal behavior
// :70:17: error: use of undefined value here causes illegal behavior
// :70:17: error: use of undefined value here causes illegal behavior
// :70:17: error: use of undefined value here causes illegal behavior
// :70:17: error: use of undefined value here causes illegal behavior
// :70:17: error: use of undefined value here causes illegal behavior
// :70:17: note: when computing vector element at index '1'
// :70:17: error: use of undefined value here causes illegal behavior
// :70:17: note: when computing vector element at index '1'
// :70:17: error: use of undefined value here causes illegal behavior
// :70:17: note: when computing vector element at index '1'
// :70:17: error: use of undefined value here causes illegal behavior
// :70:17: note: when computing vector element at index '1'
// :70:17: error: use of undefined value here causes illegal behavior
// :70:17: note: when computing vector element at index '0'
// :70:17: error: use of undefined value here causes illegal behavior
// :70:17: note: when computing vector element at index '0'
// :70:17: error: use of undefined value here causes illegal behavior
// :70:17: note: when computing vector element at index '0'
// :70:17: error: use of undefined value here causes illegal behavior
// :70:17: note: when computing vector element at index '0'
// :70:17: error: use of undefined value here causes illegal behavior
// :70:17: error: use of undefined value here causes illegal behavior
// :70:17: error: use of undefined value here causes illegal behavior
// :70:17: error: use of undefined value here causes illegal behavior
// :70:17: error: use of undefined value here causes illegal behavior
// :70:17: error: use of undefined value here causes illegal behavior
// :70:17: error: use of undefined value here causes illegal behavior
// :70:17: note: when computing vector element at index '1'
// :70:17: error: use of undefined value here causes illegal behavior
// :70:17: note: when computing vector element at index '1'
// :70:17: error: use of undefined value here causes illegal behavior
// :70:17: note: when computing vector element at index '1'
// :70:17: error: use of undefined value here causes illegal behavior
// :70:17: note: when computing vector element at index '1'
// :70:17: error: use of undefined value here causes illegal behavior
// :70:17: note: when computing vector element at index '0'
// :70:17: error: use of undefined value here causes illegal behavior
// :70:17: note: when computing vector element at index '0'
// :70:17: error: use of undefined value here causes illegal behavior
// :70:17: note: when computing vector element at index '0'
// :70:17: error: use of undefined value here causes illegal behavior
// :70:17: note: when computing vector element at index '0'
// :70:17: error: use of undefined value here causes illegal behavior
// :70:17: error: use of undefined value here causes illegal behavior
// :70:17: error: use of undefined value here causes illegal behavior
// :70:17: error: use of undefined value here causes illegal behavior
// :70:17: error: use of undefined value here causes illegal behavior
// :70:17: error: use of undefined value here causes illegal behavior
// :70:17: error: use of undefined value here causes illegal behavior
// :70:17: note: when computing vector element at index '1'
// :70:17: error: use of undefined value here causes illegal behavior
// :70:17: note: when computing vector element at index '1'
// :70:17: error: use of undefined value here causes illegal behavior
// :70:17: note: when computing vector element at index '1'
// :70:17: error: use of undefined value here causes illegal behavior
// :70:17: note: when computing vector element at index '1'
// :70:17: error: use of undefined value here causes illegal behavior
// :70:17: note: when computing vector element at index '0'
// :70:17: error: use of undefined value here causes illegal behavior
// :70:17: note: when computing vector element at index '0'
// :70:17: error: use of undefined value here causes illegal behavior
// :70:17: note: when computing vector element at index '0'
// :70:17: error: use of undefined value here causes illegal behavior
// :70:17: note: when computing vector element at index '0'
// :70:17: error: use of undefined value here causes illegal behavior
// :70:17: error: use of undefined value here causes illegal behavior
// :70:17: error: use of undefined value here causes illegal behavior
// :70:17: error: use of undefined value here causes illegal behavior
// :70:17: error: use of undefined value here causes illegal behavior
// :70:17: error: use of undefined value here causes illegal behavior
// :70:17: error: use of undefined value here causes illegal behavior
// :70:17: note: when computing vector element at index '1'
// :70:17: error: use of undefined value here causes illegal behavior
// :70:17: note: when computing vector element at index '1'
// :70:17: error: use of undefined value here causes illegal behavior
// :70:17: note: when computing vector element at index '1'
// :70:17: error: use of undefined value here causes illegal behavior
// :70:17: note: when computing vector element at index '1'
// :70:17: error: use of undefined value here causes illegal behavior
// :70:17: note: when computing vector element at index '0'
// :70:17: error: use of undefined value here causes illegal behavior
// :70:17: note: when computing vector element at index '0'
// :70:17: error: use of undefined value here causes illegal behavior
// :70:17: note: when computing vector element at index '0'
// :70:17: error: use of undefined value here causes illegal behavior
// :70:17: note: when computing vector element at index '0'
// :70:17: error: use of undefined value here causes illegal behavior
// :70:17: error: use of undefined value here causes illegal behavior
// :70:17: error: use of undefined value here causes illegal behavior
// :70:17: error: use of undefined value here causes illegal behavior
// :70:17: error: use of undefined value here causes illegal behavior
// :70:17: error: use of undefined value here causes illegal behavior
// :70:17: error: use of undefined value here causes illegal behavior
// :70:17: note: when computing vector element at index '1'
// :70:17: error: use of undefined value here causes illegal behavior
// :70:17: note: when computing vector element at index '1'
// :70:17: error: use of undefined value here causes illegal behavior
// :70:17: note: when computing vector element at index '1'
// :70:17: error: use of undefined value here causes illegal behavior
// :70:17: note: when computing vector element at index '1'
// :70:17: error: use of undefined value here causes illegal behavior
// :70:17: note: when computing vector element at index '0'
// :70:17: error: use of undefined value here causes illegal behavior
// :70:17: note: when computing vector element at index '0'
// :70:17: error: use of undefined value here causes illegal behavior
// :70:17: note: when computing vector element at index '0'
// :70:17: error: use of undefined value here causes illegal behavior
// :70:17: note: when computing vector element at index '0'
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: note: when computing vector element at index '1'
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: note: when computing vector element at index '1'
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
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: note: when computing vector element at index '1'
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: note: when computing vector element at index '1'
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
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: note: when computing vector element at index '1'
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: note: when computing vector element at index '1'
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
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: note: when computing vector element at index '1'
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: note: when computing vector element at index '1'
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
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: note: when computing vector element at index '1'
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: note: when computing vector element at index '1'
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
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: note: when computing vector element at index '1'
// :73:27: error: use of undefined value here causes illegal behavior
// :73:27: note: when computing vector element at index '1'
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
// :76:34: error: use of undefined value here causes illegal behavior
// :76:34: error: use of undefined value here causes illegal behavior
// :76:34: error: use of undefined value here causes illegal behavior
// :76:34: error: use of undefined value here causes illegal behavior
// :76:34: error: use of undefined value here causes illegal behavior
// :76:34: error: use of undefined value here causes illegal behavior
// :76:34: error: use of undefined value here causes illegal behavior
// :76:34: note: when computing vector element at index '1'
// :76:34: error: use of undefined value here causes illegal behavior
// :76:34: note: when computing vector element at index '1'
// :76:34: error: use of undefined value here causes illegal behavior
// :76:34: note: when computing vector element at index '1'
// :76:34: error: use of undefined value here causes illegal behavior
// :76:34: note: when computing vector element at index '1'
// :76:34: error: use of undefined value here causes illegal behavior
// :76:34: note: when computing vector element at index '0'
// :76:34: error: use of undefined value here causes illegal behavior
// :76:34: note: when computing vector element at index '0'
// :76:34: error: use of undefined value here causes illegal behavior
// :76:34: note: when computing vector element at index '0'
// :76:34: error: use of undefined value here causes illegal behavior
// :76:34: note: when computing vector element at index '0'
// :76:34: error: use of undefined value here causes illegal behavior
// :76:34: error: use of undefined value here causes illegal behavior
// :76:34: error: use of undefined value here causes illegal behavior
// :76:34: error: use of undefined value here causes illegal behavior
// :76:34: error: use of undefined value here causes illegal behavior
// :76:34: error: use of undefined value here causes illegal behavior
// :76:34: error: use of undefined value here causes illegal behavior
// :76:34: note: when computing vector element at index '1'
// :76:34: error: use of undefined value here causes illegal behavior
// :76:34: note: when computing vector element at index '1'
// :76:34: error: use of undefined value here causes illegal behavior
// :76:34: note: when computing vector element at index '1'
// :76:34: error: use of undefined value here causes illegal behavior
// :76:34: note: when computing vector element at index '1'
// :76:34: error: use of undefined value here causes illegal behavior
// :76:34: note: when computing vector element at index '0'
// :76:34: error: use of undefined value here causes illegal behavior
// :76:34: note: when computing vector element at index '0'
// :76:34: error: use of undefined value here causes illegal behavior
// :76:34: note: when computing vector element at index '0'
// :76:34: error: use of undefined value here causes illegal behavior
// :76:34: note: when computing vector element at index '0'
// :76:34: error: use of undefined value here causes illegal behavior
// :76:34: error: use of undefined value here causes illegal behavior
// :76:34: error: use of undefined value here causes illegal behavior
// :76:34: error: use of undefined value here causes illegal behavior
// :76:34: error: use of undefined value here causes illegal behavior
// :76:34: error: use of undefined value here causes illegal behavior
// :76:34: error: use of undefined value here causes illegal behavior
// :76:34: note: when computing vector element at index '1'
// :76:34: error: use of undefined value here causes illegal behavior
// :76:34: note: when computing vector element at index '1'
// :76:34: error: use of undefined value here causes illegal behavior
// :76:34: note: when computing vector element at index '1'
// :76:34: error: use of undefined value here causes illegal behavior
// :76:34: note: when computing vector element at index '1'
// :76:34: error: use of undefined value here causes illegal behavior
// :76:34: note: when computing vector element at index '0'
// :76:34: error: use of undefined value here causes illegal behavior
// :76:34: note: when computing vector element at index '0'
// :76:34: error: use of undefined value here causes illegal behavior
// :76:34: note: when computing vector element at index '0'
// :76:34: error: use of undefined value here causes illegal behavior
// :76:34: note: when computing vector element at index '0'
// :76:34: error: use of undefined value here causes illegal behavior
// :76:34: error: use of undefined value here causes illegal behavior
// :76:34: error: use of undefined value here causes illegal behavior
// :76:34: error: use of undefined value here causes illegal behavior
// :76:34: error: use of undefined value here causes illegal behavior
// :76:34: error: use of undefined value here causes illegal behavior
// :76:34: error: use of undefined value here causes illegal behavior
// :76:34: note: when computing vector element at index '1'
// :76:34: error: use of undefined value here causes illegal behavior
// :76:34: note: when computing vector element at index '1'
// :76:34: error: use of undefined value here causes illegal behavior
// :76:34: note: when computing vector element at index '1'
// :76:34: error: use of undefined value here causes illegal behavior
// :76:34: note: when computing vector element at index '1'
// :76:34: error: use of undefined value here causes illegal behavior
// :76:34: note: when computing vector element at index '0'
// :76:34: error: use of undefined value here causes illegal behavior
// :76:34: note: when computing vector element at index '0'
// :76:34: error: use of undefined value here causes illegal behavior
// :76:34: note: when computing vector element at index '0'
// :76:34: error: use of undefined value here causes illegal behavior
// :76:34: note: when computing vector element at index '0'
// :76:34: error: use of undefined value here causes illegal behavior
// :76:34: error: use of undefined value here causes illegal behavior
// :76:34: error: use of undefined value here causes illegal behavior
// :76:34: error: use of undefined value here causes illegal behavior
// :76:34: error: use of undefined value here causes illegal behavior
// :76:34: error: use of undefined value here causes illegal behavior
// :76:34: error: use of undefined value here causes illegal behavior
// :76:34: note: when computing vector element at index '1'
// :76:34: error: use of undefined value here causes illegal behavior
// :76:34: note: when computing vector element at index '1'
// :76:34: error: use of undefined value here causes illegal behavior
// :76:34: note: when computing vector element at index '1'
// :76:34: error: use of undefined value here causes illegal behavior
// :76:34: note: when computing vector element at index '1'
// :76:34: error: use of undefined value here causes illegal behavior
// :76:34: note: when computing vector element at index '0'
// :76:34: error: use of undefined value here causes illegal behavior
// :76:34: note: when computing vector element at index '0'
// :76:34: error: use of undefined value here causes illegal behavior
// :76:34: note: when computing vector element at index '0'
// :76:34: error: use of undefined value here causes illegal behavior
// :76:34: note: when computing vector element at index '0'
// :76:34: error: use of undefined value here causes illegal behavior
// :76:34: error: use of undefined value here causes illegal behavior
// :76:34: error: use of undefined value here causes illegal behavior
// :76:34: error: use of undefined value here causes illegal behavior
// :76:34: error: use of undefined value here causes illegal behavior
// :76:34: error: use of undefined value here causes illegal behavior
// :76:34: error: use of undefined value here causes illegal behavior
// :76:34: note: when computing vector element at index '1'
// :76:34: error: use of undefined value here causes illegal behavior
// :76:34: note: when computing vector element at index '1'
// :76:34: error: use of undefined value here causes illegal behavior
// :76:34: note: when computing vector element at index '1'
// :76:34: error: use of undefined value here causes illegal behavior
// :76:34: note: when computing vector element at index '1'
// :76:34: error: use of undefined value here causes illegal behavior
// :76:34: note: when computing vector element at index '0'
// :76:34: error: use of undefined value here causes illegal behavior
// :76:34: note: when computing vector element at index '0'
// :76:34: error: use of undefined value here causes illegal behavior
// :76:34: note: when computing vector element at index '0'
// :76:34: error: use of undefined value here causes illegal behavior
// :76:34: note: when computing vector element at index '0'
// :79:17: error: use of undefined value here causes illegal behavior
// :79:17: error: use of undefined value here causes illegal behavior
// :79:17: error: use of undefined value here causes illegal behavior
// :79:17: error: use of undefined value here causes illegal behavior
// :79:17: error: use of undefined value here causes illegal behavior
// :79:17: error: use of undefined value here causes illegal behavior
// :79:17: error: use of undefined value here causes illegal behavior
// :79:17: note: when computing vector element at index '1'
// :79:17: error: use of undefined value here causes illegal behavior
// :79:17: note: when computing vector element at index '1'
// :79:17: error: use of undefined value here causes illegal behavior
// :79:17: note: when computing vector element at index '1'
// :79:17: error: use of undefined value here causes illegal behavior
// :79:17: note: when computing vector element at index '1'
// :79:17: error: use of undefined value here causes illegal behavior
// :79:17: note: when computing vector element at index '0'
// :79:17: error: use of undefined value here causes illegal behavior
// :79:17: note: when computing vector element at index '0'
// :79:17: error: use of undefined value here causes illegal behavior
// :79:17: note: when computing vector element at index '0'
// :79:17: error: use of undefined value here causes illegal behavior
// :79:17: note: when computing vector element at index '0'
// :79:17: error: use of undefined value here causes illegal behavior
// :79:17: error: use of undefined value here causes illegal behavior
// :79:17: error: use of undefined value here causes illegal behavior
// :79:17: error: use of undefined value here causes illegal behavior
// :79:17: error: use of undefined value here causes illegal behavior
// :79:17: error: use of undefined value here causes illegal behavior
// :79:17: error: use of undefined value here causes illegal behavior
// :79:17: note: when computing vector element at index '1'
// :79:17: error: use of undefined value here causes illegal behavior
// :79:17: note: when computing vector element at index '1'
// :79:17: error: use of undefined value here causes illegal behavior
// :79:17: note: when computing vector element at index '1'
// :79:17: error: use of undefined value here causes illegal behavior
// :79:17: note: when computing vector element at index '1'
// :79:17: error: use of undefined value here causes illegal behavior
// :79:17: note: when computing vector element at index '0'
// :79:17: error: use of undefined value here causes illegal behavior
// :79:17: note: when computing vector element at index '0'
// :79:17: error: use of undefined value here causes illegal behavior
// :79:17: note: when computing vector element at index '0'
// :79:17: error: use of undefined value here causes illegal behavior
// :79:17: note: when computing vector element at index '0'
// :79:17: error: use of undefined value here causes illegal behavior
// :79:17: error: use of undefined value here causes illegal behavior
// :79:17: error: use of undefined value here causes illegal behavior
// :79:17: error: use of undefined value here causes illegal behavior
// :79:17: error: use of undefined value here causes illegal behavior
// :79:17: error: use of undefined value here causes illegal behavior
// :79:17: error: use of undefined value here causes illegal behavior
// :79:17: note: when computing vector element at index '1'
// :79:17: error: use of undefined value here causes illegal behavior
// :79:17: note: when computing vector element at index '1'
// :79:17: error: use of undefined value here causes illegal behavior
// :79:17: note: when computing vector element at index '1'
// :79:17: error: use of undefined value here causes illegal behavior
// :79:17: note: when computing vector element at index '1'
// :79:17: error: use of undefined value here causes illegal behavior
// :79:17: note: when computing vector element at index '0'
// :79:17: error: use of undefined value here causes illegal behavior
// :79:17: note: when computing vector element at index '0'
// :79:17: error: use of undefined value here causes illegal behavior
// :79:17: note: when computing vector element at index '0'
// :79:17: error: use of undefined value here causes illegal behavior
// :79:17: note: when computing vector element at index '0'
// :79:17: error: use of undefined value here causes illegal behavior
// :79:17: error: use of undefined value here causes illegal behavior
// :79:17: error: use of undefined value here causes illegal behavior
// :79:17: error: use of undefined value here causes illegal behavior
// :79:17: error: use of undefined value here causes illegal behavior
// :79:17: error: use of undefined value here causes illegal behavior
// :79:17: error: use of undefined value here causes illegal behavior
// :79:17: note: when computing vector element at index '1'
// :79:17: error: use of undefined value here causes illegal behavior
// :79:17: note: when computing vector element at index '1'
// :79:17: error: use of undefined value here causes illegal behavior
// :79:17: note: when computing vector element at index '1'
// :79:17: error: use of undefined value here causes illegal behavior
// :79:17: note: when computing vector element at index '1'
// :79:17: error: use of undefined value here causes illegal behavior
// :79:17: note: when computing vector element at index '0'
// :79:17: error: use of undefined value here causes illegal behavior
// :79:17: note: when computing vector element at index '0'
// :79:17: error: use of undefined value here causes illegal behavior
// :79:17: note: when computing vector element at index '0'
// :79:17: error: use of undefined value here causes illegal behavior
// :79:17: note: when computing vector element at index '0'
// :79:17: error: use of undefined value here causes illegal behavior
// :79:17: error: use of undefined value here causes illegal behavior
// :79:17: error: use of undefined value here causes illegal behavior
// :79:17: error: use of undefined value here causes illegal behavior
// :79:17: error: use of undefined value here causes illegal behavior
// :79:17: error: use of undefined value here causes illegal behavior
// :79:17: error: use of undefined value here causes illegal behavior
// :79:17: note: when computing vector element at index '1'
// :79:17: error: use of undefined value here causes illegal behavior
// :79:17: note: when computing vector element at index '1'
// :79:17: error: use of undefined value here causes illegal behavior
// :79:17: note: when computing vector element at index '1'
// :79:17: error: use of undefined value here causes illegal behavior
// :79:17: note: when computing vector element at index '1'
// :79:17: error: use of undefined value here causes illegal behavior
// :79:17: note: when computing vector element at index '0'
// :79:17: error: use of undefined value here causes illegal behavior
// :79:17: note: when computing vector element at index '0'
// :79:17: error: use of undefined value here causes illegal behavior
// :79:17: note: when computing vector element at index '0'
// :79:17: error: use of undefined value here causes illegal behavior
// :79:17: note: when computing vector element at index '0'
// :79:17: error: use of undefined value here causes illegal behavior
// :79:17: error: use of undefined value here causes illegal behavior
// :79:17: error: use of undefined value here causes illegal behavior
// :79:17: error: use of undefined value here causes illegal behavior
// :79:17: error: use of undefined value here causes illegal behavior
// :79:17: error: use of undefined value here causes illegal behavior
// :79:17: error: use of undefined value here causes illegal behavior
// :79:17: note: when computing vector element at index '1'
// :79:17: error: use of undefined value here causes illegal behavior
// :79:17: note: when computing vector element at index '1'
// :79:17: error: use of undefined value here causes illegal behavior
// :79:17: note: when computing vector element at index '1'
// :79:17: error: use of undefined value here causes illegal behavior
// :79:17: note: when computing vector element at index '1'
// :79:17: error: use of undefined value here causes illegal behavior
// :79:17: note: when computing vector element at index '0'
// :79:17: error: use of undefined value here causes illegal behavior
// :79:17: note: when computing vector element at index '0'
// :79:17: error: use of undefined value here causes illegal behavior
// :79:17: note: when computing vector element at index '0'
// :79:17: error: use of undefined value here causes illegal behavior
// :79:17: note: when computing vector element at index '0'
// :82:27: error: use of undefined value here causes illegal behavior
// :82:27: error: use of undefined value here causes illegal behavior
// :82:27: error: use of undefined value here causes illegal behavior
// :82:27: error: use of undefined value here causes illegal behavior
// :82:27: error: use of undefined value here causes illegal behavior
// :82:27: error: use of undefined value here causes illegal behavior
// :82:27: error: use of undefined value here causes illegal behavior
// :82:27: note: when computing vector element at index '1'
// :82:27: error: use of undefined value here causes illegal behavior
// :82:27: note: when computing vector element at index '1'
// :82:27: error: use of undefined value here causes illegal behavior
// :82:27: note: when computing vector element at index '1'
// :82:27: error: use of undefined value here causes illegal behavior
// :82:27: note: when computing vector element at index '1'
// :82:27: error: use of undefined value here causes illegal behavior
// :82:27: note: when computing vector element at index '0'
// :82:27: error: use of undefined value here causes illegal behavior
// :82:27: note: when computing vector element at index '0'
// :82:27: error: use of undefined value here causes illegal behavior
// :82:27: note: when computing vector element at index '0'
// :82:27: error: use of undefined value here causes illegal behavior
// :82:27: note: when computing vector element at index '0'
// :82:27: error: use of undefined value here causes illegal behavior
// :82:27: error: use of undefined value here causes illegal behavior
// :82:27: error: use of undefined value here causes illegal behavior
// :82:27: error: use of undefined value here causes illegal behavior
// :82:27: error: use of undefined value here causes illegal behavior
// :82:27: error: use of undefined value here causes illegal behavior
// :82:27: error: use of undefined value here causes illegal behavior
// :82:27: note: when computing vector element at index '1'
// :82:27: error: use of undefined value here causes illegal behavior
// :82:27: note: when computing vector element at index '1'
// :82:27: error: use of undefined value here causes illegal behavior
// :82:27: note: when computing vector element at index '1'
// :82:27: error: use of undefined value here causes illegal behavior
// :82:27: note: when computing vector element at index '1'
// :82:27: error: use of undefined value here causes illegal behavior
// :82:27: note: when computing vector element at index '0'
// :82:27: error: use of undefined value here causes illegal behavior
// :82:27: note: when computing vector element at index '0'
// :82:27: error: use of undefined value here causes illegal behavior
// :82:27: note: when computing vector element at index '0'
// :82:27: error: use of undefined value here causes illegal behavior
// :82:27: note: when computing vector element at index '0'
// :82:27: error: use of undefined value here causes illegal behavior
// :82:27: error: use of undefined value here causes illegal behavior
// :82:27: error: use of undefined value here causes illegal behavior
// :82:27: error: use of undefined value here causes illegal behavior
// :82:27: error: use of undefined value here causes illegal behavior
// :82:27: error: use of undefined value here causes illegal behavior
// :82:27: error: use of undefined value here causes illegal behavior
// :82:27: note: when computing vector element at index '1'
// :82:27: error: use of undefined value here causes illegal behavior
// :82:27: note: when computing vector element at index '1'
// :82:27: error: use of undefined value here causes illegal behavior
// :82:27: note: when computing vector element at index '1'
// :82:27: error: use of undefined value here causes illegal behavior
// :82:27: note: when computing vector element at index '1'
// :82:27: error: use of undefined value here causes illegal behavior
// :82:27: note: when computing vector element at index '0'
// :82:27: error: use of undefined value here causes illegal behavior
// :82:27: note: when computing vector element at index '0'
// :82:27: error: use of undefined value here causes illegal behavior
// :82:27: note: when computing vector element at index '0'
// :82:27: error: use of undefined value here causes illegal behavior
// :82:27: note: when computing vector element at index '0'
// :82:27: error: use of undefined value here causes illegal behavior
// :82:27: error: use of undefined value here causes illegal behavior
// :82:27: error: use of undefined value here causes illegal behavior
// :82:27: error: use of undefined value here causes illegal behavior
// :82:27: error: use of undefined value here causes illegal behavior
// :82:27: error: use of undefined value here causes illegal behavior
// :82:27: error: use of undefined value here causes illegal behavior
// :82:27: note: when computing vector element at index '1'
// :82:27: error: use of undefined value here causes illegal behavior
// :82:27: note: when computing vector element at index '1'
// :82:27: error: use of undefined value here causes illegal behavior
// :82:27: note: when computing vector element at index '1'
// :82:27: error: use of undefined value here causes illegal behavior
// :82:27: note: when computing vector element at index '1'
// :82:27: error: use of undefined value here causes illegal behavior
// :82:27: note: when computing vector element at index '0'
// :82:27: error: use of undefined value here causes illegal behavior
// :82:27: note: when computing vector element at index '0'
// :82:27: error: use of undefined value here causes illegal behavior
// :82:27: note: when computing vector element at index '0'
// :82:27: error: use of undefined value here causes illegal behavior
// :82:27: note: when computing vector element at index '0'
// :82:27: error: use of undefined value here causes illegal behavior
// :82:27: error: use of undefined value here causes illegal behavior
// :82:27: error: use of undefined value here causes illegal behavior
// :82:27: error: use of undefined value here causes illegal behavior
// :82:27: error: use of undefined value here causes illegal behavior
// :82:27: error: use of undefined value here causes illegal behavior
// :82:27: error: use of undefined value here causes illegal behavior
// :82:27: note: when computing vector element at index '1'
// :82:27: error: use of undefined value here causes illegal behavior
// :82:27: note: when computing vector element at index '1'
// :82:27: error: use of undefined value here causes illegal behavior
// :82:27: note: when computing vector element at index '1'
// :82:27: error: use of undefined value here causes illegal behavior
// :82:27: note: when computing vector element at index '1'
// :82:27: error: use of undefined value here causes illegal behavior
// :82:27: note: when computing vector element at index '0'
// :82:27: error: use of undefined value here causes illegal behavior
// :82:27: note: when computing vector element at index '0'
// :82:27: error: use of undefined value here causes illegal behavior
// :82:27: note: when computing vector element at index '0'
// :82:27: error: use of undefined value here causes illegal behavior
// :82:27: note: when computing vector element at index '0'
// :82:27: error: use of undefined value here causes illegal behavior
// :82:27: error: use of undefined value here causes illegal behavior
// :82:27: error: use of undefined value here causes illegal behavior
// :82:27: error: use of undefined value here causes illegal behavior
// :82:27: error: use of undefined value here causes illegal behavior
// :82:27: error: use of undefined value here causes illegal behavior
// :82:27: error: use of undefined value here causes illegal behavior
// :82:27: note: when computing vector element at index '1'
// :82:27: error: use of undefined value here causes illegal behavior
// :82:27: note: when computing vector element at index '1'
// :82:27: error: use of undefined value here causes illegal behavior
// :82:27: note: when computing vector element at index '1'
// :82:27: error: use of undefined value here causes illegal behavior
// :82:27: note: when computing vector element at index '1'
// :82:27: error: use of undefined value here causes illegal behavior
// :82:27: note: when computing vector element at index '0'
// :82:27: error: use of undefined value here causes illegal behavior
// :82:27: note: when computing vector element at index '0'
// :82:27: error: use of undefined value here causes illegal behavior
// :82:27: note: when computing vector element at index '0'
// :82:27: error: use of undefined value here causes illegal behavior
// :82:27: note: when computing vector element at index '0'
// :87:17: error: use of undefined value here causes illegal behavior
// :87:17: error: use of undefined value here causes illegal behavior
// :87:17: note: when computing vector element at index '0'
// :87:17: error: use of undefined value here causes illegal behavior
// :87:17: note: when computing vector element at index '0'
// :87:17: error: use of undefined value here causes illegal behavior
// :87:17: note: when computing vector element at index '0'
// :87:17: error: use of undefined value here causes illegal behavior
// :87:17: note: when computing vector element at index '1'
// :87:17: error: use of undefined value here causes illegal behavior
// :87:17: note: when computing vector element at index '0'
// :87:17: error: use of undefined value here causes illegal behavior
// :87:17: note: when computing vector element at index '0'
// :87:17: error: use of undefined value here causes illegal behavior
// :87:17: note: when computing vector element at index '0'
// :87:17: error: use of undefined value here causes illegal behavior
// :87:17: error: use of undefined value here causes illegal behavior
// :87:17: note: when computing vector element at index '0'
// :87:17: error: use of undefined value here causes illegal behavior
// :87:17: note: when computing vector element at index '0'
// :87:17: error: use of undefined value here causes illegal behavior
// :87:17: note: when computing vector element at index '0'
// :87:17: error: use of undefined value here causes illegal behavior
// :87:17: note: when computing vector element at index '1'
// :87:17: error: use of undefined value here causes illegal behavior
// :87:17: note: when computing vector element at index '0'
// :87:17: error: use of undefined value here causes illegal behavior
// :87:17: note: when computing vector element at index '0'
// :87:17: error: use of undefined value here causes illegal behavior
// :87:17: note: when computing vector element at index '0'
// :87:17: error: use of undefined value here causes illegal behavior
// :87:17: error: use of undefined value here causes illegal behavior
// :87:17: note: when computing vector element at index '0'
// :87:17: error: use of undefined value here causes illegal behavior
// :87:17: note: when computing vector element at index '0'
// :87:17: error: use of undefined value here causes illegal behavior
// :87:17: note: when computing vector element at index '0'
// :87:17: error: use of undefined value here causes illegal behavior
// :87:17: note: when computing vector element at index '1'
// :87:17: error: use of undefined value here causes illegal behavior
// :87:17: note: when computing vector element at index '0'
// :87:17: error: use of undefined value here causes illegal behavior
// :87:17: note: when computing vector element at index '0'
// :87:17: error: use of undefined value here causes illegal behavior
// :87:17: note: when computing vector element at index '0'
// :87:17: error: use of undefined value here causes illegal behavior
// :87:17: error: use of undefined value here causes illegal behavior
// :87:17: note: when computing vector element at index '0'
// :87:17: error: use of undefined value here causes illegal behavior
// :87:17: note: when computing vector element at index '0'
// :87:17: error: use of undefined value here causes illegal behavior
// :87:17: note: when computing vector element at index '0'
// :87:17: error: use of undefined value here causes illegal behavior
// :87:17: note: when computing vector element at index '1'
// :87:17: error: use of undefined value here causes illegal behavior
// :87:17: note: when computing vector element at index '0'
// :87:17: error: use of undefined value here causes illegal behavior
// :87:17: note: when computing vector element at index '0'
// :87:17: error: use of undefined value here causes illegal behavior
// :87:17: note: when computing vector element at index '0'
// :87:17: error: use of undefined value here causes illegal behavior
// :87:17: error: use of undefined value here causes illegal behavior
// :87:17: note: when computing vector element at index '0'
// :87:17: error: use of undefined value here causes illegal behavior
// :87:17: note: when computing vector element at index '0'
// :87:17: error: use of undefined value here causes illegal behavior
// :87:17: note: when computing vector element at index '0'
// :87:17: error: use of undefined value here causes illegal behavior
// :87:17: note: when computing vector element at index '1'
// :87:17: error: use of undefined value here causes illegal behavior
// :87:17: note: when computing vector element at index '0'
// :87:17: error: use of undefined value here causes illegal behavior
// :87:17: note: when computing vector element at index '0'
// :87:17: error: use of undefined value here causes illegal behavior
// :87:17: note: when computing vector element at index '0'
// :87:17: error: use of undefined value here causes illegal behavior
// :87:17: error: use of undefined value here causes illegal behavior
// :87:17: note: when computing vector element at index '0'
// :87:17: error: use of undefined value here causes illegal behavior
// :87:17: note: when computing vector element at index '0'
// :87:17: error: use of undefined value here causes illegal behavior
// :87:17: note: when computing vector element at index '0'
// :87:17: error: use of undefined value here causes illegal behavior
// :87:17: note: when computing vector element at index '1'
// :87:17: error: use of undefined value here causes illegal behavior
// :87:17: note: when computing vector element at index '0'
// :87:17: error: use of undefined value here causes illegal behavior
// :87:17: note: when computing vector element at index '0'
// :87:17: error: use of undefined value here causes illegal behavior
// :87:17: note: when computing vector element at index '0'
// :87:22: error: use of undefined value here causes illegal behavior
// :87:22: error: use of undefined value here causes illegal behavior
// :87:22: note: when computing vector element at index '0'
// :87:22: error: use of undefined value here causes illegal behavior
// :87:22: note: when computing vector element at index '0'
// :87:22: error: use of undefined value here causes illegal behavior
// :87:22: note: when computing vector element at index '1'
// :87:22: error: use of undefined value here causes illegal behavior
// :87:22: note: when computing vector element at index '0'
// :87:22: error: use of undefined value here causes illegal behavior
// :87:22: note: when computing vector element at index '0'
// :87:22: error: use of undefined value here causes illegal behavior
// :87:22: error: use of undefined value here causes illegal behavior
// :87:22: note: when computing vector element at index '0'
// :87:22: error: use of undefined value here causes illegal behavior
// :87:22: note: when computing vector element at index '0'
// :87:22: error: use of undefined value here causes illegal behavior
// :87:22: note: when computing vector element at index '1'
// :87:22: error: use of undefined value here causes illegal behavior
// :87:22: note: when computing vector element at index '0'
// :87:22: error: use of undefined value here causes illegal behavior
// :87:22: note: when computing vector element at index '0'
// :87:22: error: use of undefined value here causes illegal behavior
// :87:22: error: use of undefined value here causes illegal behavior
// :87:22: note: when computing vector element at index '0'
// :87:22: error: use of undefined value here causes illegal behavior
// :87:22: note: when computing vector element at index '0'
// :87:22: error: use of undefined value here causes illegal behavior
// :87:22: note: when computing vector element at index '1'
// :87:22: error: use of undefined value here causes illegal behavior
// :87:22: note: when computing vector element at index '0'
// :87:22: error: use of undefined value here causes illegal behavior
// :87:22: note: when computing vector element at index '0'
// :87:22: error: use of undefined value here causes illegal behavior
// :87:22: error: use of undefined value here causes illegal behavior
// :87:22: note: when computing vector element at index '0'
// :87:22: error: use of undefined value here causes illegal behavior
// :87:22: note: when computing vector element at index '0'
// :87:22: error: use of undefined value here causes illegal behavior
// :87:22: note: when computing vector element at index '1'
// :87:22: error: use of undefined value here causes illegal behavior
// :87:22: note: when computing vector element at index '0'
// :87:22: error: use of undefined value here causes illegal behavior
// :87:22: note: when computing vector element at index '0'
// :87:22: error: use of undefined value here causes illegal behavior
// :87:22: error: use of undefined value here causes illegal behavior
// :87:22: note: when computing vector element at index '0'
// :87:22: error: use of undefined value here causes illegal behavior
// :87:22: note: when computing vector element at index '0'
// :87:22: error: use of undefined value here causes illegal behavior
// :87:22: note: when computing vector element at index '1'
// :87:22: error: use of undefined value here causes illegal behavior
// :87:22: note: when computing vector element at index '0'
// :87:22: error: use of undefined value here causes illegal behavior
// :87:22: note: when computing vector element at index '0'
// :87:22: error: use of undefined value here causes illegal behavior
// :87:22: error: use of undefined value here causes illegal behavior
// :87:22: note: when computing vector element at index '0'
// :87:22: error: use of undefined value here causes illegal behavior
// :87:22: note: when computing vector element at index '0'
// :87:22: error: use of undefined value here causes illegal behavior
// :87:22: note: when computing vector element at index '1'
// :87:22: error: use of undefined value here causes illegal behavior
// :87:22: note: when computing vector element at index '0'
// :87:22: error: use of undefined value here causes illegal behavior
// :87:22: note: when computing vector element at index '0'
// :90:27: error: use of undefined value here causes illegal behavior
// :90:27: error: use of undefined value here causes illegal behavior
// :90:27: note: when computing vector element at index '0'
// :90:27: error: use of undefined value here causes illegal behavior
// :90:27: note: when computing vector element at index '0'
// :90:27: error: use of undefined value here causes illegal behavior
// :90:27: note: when computing vector element at index '0'
// :90:27: error: use of undefined value here causes illegal behavior
// :90:27: note: when computing vector element at index '1'
// :90:27: error: use of undefined value here causes illegal behavior
// :90:27: note: when computing vector element at index '0'
// :90:27: error: use of undefined value here causes illegal behavior
// :90:27: note: when computing vector element at index '0'
// :90:27: error: use of undefined value here causes illegal behavior
// :90:27: note: when computing vector element at index '0'
// :90:27: error: use of undefined value here causes illegal behavior
// :90:27: error: use of undefined value here causes illegal behavior
// :90:27: note: when computing vector element at index '0'
// :90:27: error: use of undefined value here causes illegal behavior
// :90:27: note: when computing vector element at index '0'
// :90:27: error: use of undefined value here causes illegal behavior
// :90:27: note: when computing vector element at index '0'
// :90:27: error: use of undefined value here causes illegal behavior
// :90:27: note: when computing vector element at index '1'
// :90:27: error: use of undefined value here causes illegal behavior
// :90:27: note: when computing vector element at index '0'
// :90:27: error: use of undefined value here causes illegal behavior
// :90:27: note: when computing vector element at index '0'
// :90:27: error: use of undefined value here causes illegal behavior
// :90:27: note: when computing vector element at index '0'
// :90:27: error: use of undefined value here causes illegal behavior
// :90:27: error: use of undefined value here causes illegal behavior
// :90:27: note: when computing vector element at index '0'
// :90:27: error: use of undefined value here causes illegal behavior
// :90:27: note: when computing vector element at index '0'
// :90:27: error: use of undefined value here causes illegal behavior
// :90:27: note: when computing vector element at index '0'
// :90:27: error: use of undefined value here causes illegal behavior
// :90:27: note: when computing vector element at index '1'
// :90:27: error: use of undefined value here causes illegal behavior
// :90:27: note: when computing vector element at index '0'
// :90:27: error: use of undefined value here causes illegal behavior
// :90:27: note: when computing vector element at index '0'
// :90:27: error: use of undefined value here causes illegal behavior
// :90:27: note: when computing vector element at index '0'
// :90:27: error: use of undefined value here causes illegal behavior
// :90:27: error: use of undefined value here causes illegal behavior
// :90:27: note: when computing vector element at index '0'
// :90:27: error: use of undefined value here causes illegal behavior
// :90:27: note: when computing vector element at index '0'
// :90:27: error: use of undefined value here causes illegal behavior
// :90:27: note: when computing vector element at index '0'
// :90:27: error: use of undefined value here causes illegal behavior
// :90:27: note: when computing vector element at index '1'
// :90:27: error: use of undefined value here causes illegal behavior
// :90:27: note: when computing vector element at index '0'
// :90:27: error: use of undefined value here causes illegal behavior
// :90:27: note: when computing vector element at index '0'
// :90:27: error: use of undefined value here causes illegal behavior
// :90:27: note: when computing vector element at index '0'
// :90:27: error: use of undefined value here causes illegal behavior
// :90:27: error: use of undefined value here causes illegal behavior
// :90:27: note: when computing vector element at index '0'
// :90:27: error: use of undefined value here causes illegal behavior
// :90:27: note: when computing vector element at index '0'
// :90:27: error: use of undefined value here causes illegal behavior
// :90:27: note: when computing vector element at index '0'
// :90:27: error: use of undefined value here causes illegal behavior
// :90:27: note: when computing vector element at index '1'
// :90:27: error: use of undefined value here causes illegal behavior
// :90:27: note: when computing vector element at index '0'
// :90:27: error: use of undefined value here causes illegal behavior
// :90:27: note: when computing vector element at index '0'
// :90:27: error: use of undefined value here causes illegal behavior
// :90:27: note: when computing vector element at index '0'
// :90:27: error: use of undefined value here causes illegal behavior
// :90:27: error: use of undefined value here causes illegal behavior
// :90:27: note: when computing vector element at index '0'
// :90:27: error: use of undefined value here causes illegal behavior
// :90:27: note: when computing vector element at index '0'
// :90:27: error: use of undefined value here causes illegal behavior
// :90:27: note: when computing vector element at index '0'
// :90:27: error: use of undefined value here causes illegal behavior
// :90:27: note: when computing vector element at index '1'
// :90:27: error: use of undefined value here causes illegal behavior
// :90:27: note: when computing vector element at index '0'
// :90:27: error: use of undefined value here causes illegal behavior
// :90:27: note: when computing vector element at index '0'
// :90:27: error: use of undefined value here causes illegal behavior
// :90:27: note: when computing vector element at index '0'
// :90:30: error: use of undefined value here causes illegal behavior
// :90:30: error: use of undefined value here causes illegal behavior
// :90:30: note: when computing vector element at index '0'
// :90:30: error: use of undefined value here causes illegal behavior
// :90:30: note: when computing vector element at index '0'
// :90:30: error: use of undefined value here causes illegal behavior
// :90:30: note: when computing vector element at index '1'
// :90:30: error: use of undefined value here causes illegal behavior
// :90:30: note: when computing vector element at index '0'
// :90:30: error: use of undefined value here causes illegal behavior
// :90:30: note: when computing vector element at index '0'
// :90:30: error: use of undefined value here causes illegal behavior
// :90:30: error: use of undefined value here causes illegal behavior
// :90:30: note: when computing vector element at index '0'
// :90:30: error: use of undefined value here causes illegal behavior
// :90:30: note: when computing vector element at index '0'
// :90:30: error: use of undefined value here causes illegal behavior
// :90:30: note: when computing vector element at index '1'
// :90:30: error: use of undefined value here causes illegal behavior
// :90:30: note: when computing vector element at index '0'
// :90:30: error: use of undefined value here causes illegal behavior
// :90:30: note: when computing vector element at index '0'
// :90:30: error: use of undefined value here causes illegal behavior
// :90:30: error: use of undefined value here causes illegal behavior
// :90:30: note: when computing vector element at index '0'
// :90:30: error: use of undefined value here causes illegal behavior
// :90:30: note: when computing vector element at index '0'
// :90:30: error: use of undefined value here causes illegal behavior
// :90:30: note: when computing vector element at index '1'
// :90:30: error: use of undefined value here causes illegal behavior
// :90:30: note: when computing vector element at index '0'
// :90:30: error: use of undefined value here causes illegal behavior
// :90:30: note: when computing vector element at index '0'
// :90:30: error: use of undefined value here causes illegal behavior
// :90:30: error: use of undefined value here causes illegal behavior
// :90:30: note: when computing vector element at index '0'
// :90:30: error: use of undefined value here causes illegal behavior
// :90:30: note: when computing vector element at index '0'
// :90:30: error: use of undefined value here causes illegal behavior
// :90:30: note: when computing vector element at index '1'
// :90:30: error: use of undefined value here causes illegal behavior
// :90:30: note: when computing vector element at index '0'
// :90:30: error: use of undefined value here causes illegal behavior
// :90:30: note: when computing vector element at index '0'
// :90:30: error: use of undefined value here causes illegal behavior
// :90:30: error: use of undefined value here causes illegal behavior
// :90:30: note: when computing vector element at index '0'
// :90:30: error: use of undefined value here causes illegal behavior
// :90:30: note: when computing vector element at index '0'
// :90:30: error: use of undefined value here causes illegal behavior
// :90:30: note: when computing vector element at index '1'
// :90:30: error: use of undefined value here causes illegal behavior
// :90:30: note: when computing vector element at index '0'
// :90:30: error: use of undefined value here causes illegal behavior
// :90:30: note: when computing vector element at index '0'
// :90:30: error: use of undefined value here causes illegal behavior
// :90:30: error: use of undefined value here causes illegal behavior
// :90:30: note: when computing vector element at index '0'
// :90:30: error: use of undefined value here causes illegal behavior
// :90:30: note: when computing vector element at index '0'
// :90:30: error: use of undefined value here causes illegal behavior
// :90:30: note: when computing vector element at index '1'
// :90:30: error: use of undefined value here causes illegal behavior
// :90:30: note: when computing vector element at index '0'
// :90:30: error: use of undefined value here causes illegal behavior
// :90:30: note: when computing vector element at index '0'
// :93:34: error: use of undefined value here causes illegal behavior
// :93:34: error: use of undefined value here causes illegal behavior
// :93:34: note: when computing vector element at index '0'
// :93:34: error: use of undefined value here causes illegal behavior
// :93:34: note: when computing vector element at index '0'
// :93:34: error: use of undefined value here causes illegal behavior
// :93:34: note: when computing vector element at index '0'
// :93:34: error: use of undefined value here causes illegal behavior
// :93:34: note: when computing vector element at index '1'
// :93:34: error: use of undefined value here causes illegal behavior
// :93:34: note: when computing vector element at index '0'
// :93:34: error: use of undefined value here causes illegal behavior
// :93:34: note: when computing vector element at index '0'
// :93:34: error: use of undefined value here causes illegal behavior
// :93:34: note: when computing vector element at index '0'
// :93:34: error: use of undefined value here causes illegal behavior
// :93:34: error: use of undefined value here causes illegal behavior
// :93:34: note: when computing vector element at index '0'
// :93:34: error: use of undefined value here causes illegal behavior
// :93:34: note: when computing vector element at index '0'
// :93:34: error: use of undefined value here causes illegal behavior
// :93:34: note: when computing vector element at index '0'
// :93:34: error: use of undefined value here causes illegal behavior
// :93:34: note: when computing vector element at index '1'
// :93:34: error: use of undefined value here causes illegal behavior
// :93:34: note: when computing vector element at index '0'
// :93:34: error: use of undefined value here causes illegal behavior
// :93:34: note: when computing vector element at index '0'
// :93:34: error: use of undefined value here causes illegal behavior
// :93:34: note: when computing vector element at index '0'
// :93:34: error: use of undefined value here causes illegal behavior
// :93:34: error: use of undefined value here causes illegal behavior
// :93:34: note: when computing vector element at index '0'
// :93:34: error: use of undefined value here causes illegal behavior
// :93:34: note: when computing vector element at index '0'
// :93:34: error: use of undefined value here causes illegal behavior
// :93:34: note: when computing vector element at index '0'
// :93:34: error: use of undefined value here causes illegal behavior
// :93:34: note: when computing vector element at index '1'
// :93:34: error: use of undefined value here causes illegal behavior
// :93:34: note: when computing vector element at index '0'
// :93:34: error: use of undefined value here causes illegal behavior
// :93:34: note: when computing vector element at index '0'
// :93:34: error: use of undefined value here causes illegal behavior
// :93:34: note: when computing vector element at index '0'
// :93:34: error: use of undefined value here causes illegal behavior
// :93:34: error: use of undefined value here causes illegal behavior
// :93:34: note: when computing vector element at index '0'
// :93:34: error: use of undefined value here causes illegal behavior
// :93:34: note: when computing vector element at index '0'
// :93:34: error: use of undefined value here causes illegal behavior
// :93:34: note: when computing vector element at index '0'
// :93:34: error: use of undefined value here causes illegal behavior
// :93:34: note: when computing vector element at index '1'
// :93:34: error: use of undefined value here causes illegal behavior
// :93:34: note: when computing vector element at index '0'
// :93:34: error: use of undefined value here causes illegal behavior
// :93:34: note: when computing vector element at index '0'
// :93:34: error: use of undefined value here causes illegal behavior
// :93:34: note: when computing vector element at index '0'
// :93:34: error: use of undefined value here causes illegal behavior
// :93:34: error: use of undefined value here causes illegal behavior
// :93:34: note: when computing vector element at index '0'
// :93:34: error: use of undefined value here causes illegal behavior
// :93:34: note: when computing vector element at index '0'
// :93:34: error: use of undefined value here causes illegal behavior
// :93:34: note: when computing vector element at index '0'
// :93:34: error: use of undefined value here causes illegal behavior
// :93:34: note: when computing vector element at index '1'
// :93:34: error: use of undefined value here causes illegal behavior
// :93:34: note: when computing vector element at index '0'
// :93:34: error: use of undefined value here causes illegal behavior
// :93:34: note: when computing vector element at index '0'
// :93:34: error: use of undefined value here causes illegal behavior
// :93:34: note: when computing vector element at index '0'
// :93:34: error: use of undefined value here causes illegal behavior
// :93:34: error: use of undefined value here causes illegal behavior
// :93:34: note: when computing vector element at index '0'
// :93:34: error: use of undefined value here causes illegal behavior
// :93:34: note: when computing vector element at index '0'
// :93:34: error: use of undefined value here causes illegal behavior
// :93:34: note: when computing vector element at index '0'
// :93:34: error: use of undefined value here causes illegal behavior
// :93:34: note: when computing vector element at index '1'
// :93:34: error: use of undefined value here causes illegal behavior
// :93:34: note: when computing vector element at index '0'
// :93:34: error: use of undefined value here causes illegal behavior
// :93:34: note: when computing vector element at index '0'
// :93:34: error: use of undefined value here causes illegal behavior
// :93:34: note: when computing vector element at index '0'
// :93:37: error: use of undefined value here causes illegal behavior
// :93:37: error: use of undefined value here causes illegal behavior
// :93:37: note: when computing vector element at index '0'
// :93:37: error: use of undefined value here causes illegal behavior
// :93:37: note: when computing vector element at index '0'
// :93:37: error: use of undefined value here causes illegal behavior
// :93:37: note: when computing vector element at index '1'
// :93:37: error: use of undefined value here causes illegal behavior
// :93:37: note: when computing vector element at index '0'
// :93:37: error: use of undefined value here causes illegal behavior
// :93:37: note: when computing vector element at index '0'
// :93:37: error: use of undefined value here causes illegal behavior
// :93:37: error: use of undefined value here causes illegal behavior
// :93:37: note: when computing vector element at index '0'
// :93:37: error: use of undefined value here causes illegal behavior
// :93:37: note: when computing vector element at index '0'
// :93:37: error: use of undefined value here causes illegal behavior
// :93:37: note: when computing vector element at index '1'
// :93:37: error: use of undefined value here causes illegal behavior
// :93:37: note: when computing vector element at index '0'
// :93:37: error: use of undefined value here causes illegal behavior
// :93:37: note: when computing vector element at index '0'
// :93:37: error: use of undefined value here causes illegal behavior
// :93:37: error: use of undefined value here causes illegal behavior
// :93:37: note: when computing vector element at index '0'
// :93:37: error: use of undefined value here causes illegal behavior
// :93:37: note: when computing vector element at index '0'
// :93:37: error: use of undefined value here causes illegal behavior
// :93:37: note: when computing vector element at index '1'
// :93:37: error: use of undefined value here causes illegal behavior
// :93:37: note: when computing vector element at index '0'
// :93:37: error: use of undefined value here causes illegal behavior
// :93:37: note: when computing vector element at index '0'
// :93:37: error: use of undefined value here causes illegal behavior
// :93:37: error: use of undefined value here causes illegal behavior
// :93:37: note: when computing vector element at index '0'
// :93:37: error: use of undefined value here causes illegal behavior
// :93:37: note: when computing vector element at index '0'
// :93:37: error: use of undefined value here causes illegal behavior
// :93:37: note: when computing vector element at index '1'
// :93:37: error: use of undefined value here causes illegal behavior
// :93:37: note: when computing vector element at index '0'
// :93:37: error: use of undefined value here causes illegal behavior
// :93:37: note: when computing vector element at index '0'
// :93:37: error: use of undefined value here causes illegal behavior
// :93:37: error: use of undefined value here causes illegal behavior
// :93:37: note: when computing vector element at index '0'
// :93:37: error: use of undefined value here causes illegal behavior
// :93:37: note: when computing vector element at index '0'
// :93:37: error: use of undefined value here causes illegal behavior
// :93:37: note: when computing vector element at index '1'
// :93:37: error: use of undefined value here causes illegal behavior
// :93:37: note: when computing vector element at index '0'
// :93:37: error: use of undefined value here causes illegal behavior
// :93:37: note: when computing vector element at index '0'
// :93:37: error: use of undefined value here causes illegal behavior
// :93:37: error: use of undefined value here causes illegal behavior
// :93:37: note: when computing vector element at index '0'
// :93:37: error: use of undefined value here causes illegal behavior
// :93:37: note: when computing vector element at index '0'
// :93:37: error: use of undefined value here causes illegal behavior
// :93:37: note: when computing vector element at index '1'
// :93:37: error: use of undefined value here causes illegal behavior
// :93:37: note: when computing vector element at index '0'
// :93:37: error: use of undefined value here causes illegal behavior
// :93:37: note: when computing vector element at index '0'
// :96:17: error: use of undefined value here causes illegal behavior
// :96:17: error: use of undefined value here causes illegal behavior
// :96:17: note: when computing vector element at index '0'
// :96:17: error: use of undefined value here causes illegal behavior
// :96:17: note: when computing vector element at index '0'
// :96:17: error: use of undefined value here causes illegal behavior
// :96:17: note: when computing vector element at index '0'
// :96:17: error: use of undefined value here causes illegal behavior
// :96:17: note: when computing vector element at index '1'
// :96:17: error: use of undefined value here causes illegal behavior
// :96:17: note: when computing vector element at index '0'
// :96:17: error: use of undefined value here causes illegal behavior
// :96:17: note: when computing vector element at index '0'
// :96:17: error: use of undefined value here causes illegal behavior
// :96:17: note: when computing vector element at index '0'
// :96:17: error: use of undefined value here causes illegal behavior
// :96:17: error: use of undefined value here causes illegal behavior
// :96:17: note: when computing vector element at index '0'
// :96:17: error: use of undefined value here causes illegal behavior
// :96:17: note: when computing vector element at index '0'
// :96:17: error: use of undefined value here causes illegal behavior
// :96:17: note: when computing vector element at index '0'
// :96:17: error: use of undefined value here causes illegal behavior
// :96:17: note: when computing vector element at index '1'
// :96:17: error: use of undefined value here causes illegal behavior
// :96:17: note: when computing vector element at index '0'
// :96:17: error: use of undefined value here causes illegal behavior
// :96:17: note: when computing vector element at index '0'
// :96:17: error: use of undefined value here causes illegal behavior
// :96:17: note: when computing vector element at index '0'
// :96:17: error: use of undefined value here causes illegal behavior
// :96:17: error: use of undefined value here causes illegal behavior
// :96:17: note: when computing vector element at index '0'
// :96:17: error: use of undefined value here causes illegal behavior
// :96:17: note: when computing vector element at index '0'
// :96:17: error: use of undefined value here causes illegal behavior
// :96:17: note: when computing vector element at index '0'
// :96:17: error: use of undefined value here causes illegal behavior
// :96:17: note: when computing vector element at index '1'
// :96:17: error: use of undefined value here causes illegal behavior
// :96:17: note: when computing vector element at index '0'
// :96:17: error: use of undefined value here causes illegal behavior
// :96:17: note: when computing vector element at index '0'
// :96:17: error: use of undefined value here causes illegal behavior
// :96:17: note: when computing vector element at index '0'
// :96:17: error: use of undefined value here causes illegal behavior
// :96:17: error: use of undefined value here causes illegal behavior
// :96:17: note: when computing vector element at index '0'
// :96:17: error: use of undefined value here causes illegal behavior
// :96:17: note: when computing vector element at index '0'
// :96:17: error: use of undefined value here causes illegal behavior
// :96:17: note: when computing vector element at index '0'
// :96:17: error: use of undefined value here causes illegal behavior
// :96:17: note: when computing vector element at index '1'
// :96:17: error: use of undefined value here causes illegal behavior
// :96:17: note: when computing vector element at index '0'
// :96:17: error: use of undefined value here causes illegal behavior
// :96:17: note: when computing vector element at index '0'
// :96:17: error: use of undefined value here causes illegal behavior
// :96:17: note: when computing vector element at index '0'
// :96:17: error: use of undefined value here causes illegal behavior
// :96:17: error: use of undefined value here causes illegal behavior
// :96:17: note: when computing vector element at index '0'
// :96:17: error: use of undefined value here causes illegal behavior
// :96:17: note: when computing vector element at index '0'
// :96:17: error: use of undefined value here causes illegal behavior
// :96:17: note: when computing vector element at index '0'
// :96:17: error: use of undefined value here causes illegal behavior
// :96:17: note: when computing vector element at index '1'
// :96:17: error: use of undefined value here causes illegal behavior
// :96:17: note: when computing vector element at index '0'
// :96:17: error: use of undefined value here causes illegal behavior
// :96:17: note: when computing vector element at index '0'
// :96:17: error: use of undefined value here causes illegal behavior
// :96:17: note: when computing vector element at index '0'
// :96:17: error: use of undefined value here causes illegal behavior
// :96:17: error: use of undefined value here causes illegal behavior
// :96:17: note: when computing vector element at index '0'
// :96:17: error: use of undefined value here causes illegal behavior
// :96:17: note: when computing vector element at index '0'
// :96:17: error: use of undefined value here causes illegal behavior
// :96:17: note: when computing vector element at index '0'
// :96:17: error: use of undefined value here causes illegal behavior
// :96:17: note: when computing vector element at index '1'
// :96:17: error: use of undefined value here causes illegal behavior
// :96:17: note: when computing vector element at index '0'
// :96:17: error: use of undefined value here causes illegal behavior
// :96:17: note: when computing vector element at index '0'
// :96:17: error: use of undefined value here causes illegal behavior
// :96:17: note: when computing vector element at index '0'
// :96:22: error: use of undefined value here causes illegal behavior
// :96:22: error: use of undefined value here causes illegal behavior
// :96:22: note: when computing vector element at index '0'
// :96:22: error: use of undefined value here causes illegal behavior
// :96:22: note: when computing vector element at index '0'
// :96:22: error: use of undefined value here causes illegal behavior
// :96:22: note: when computing vector element at index '1'
// :96:22: error: use of undefined value here causes illegal behavior
// :96:22: note: when computing vector element at index '0'
// :96:22: error: use of undefined value here causes illegal behavior
// :96:22: note: when computing vector element at index '0'
// :96:22: error: use of undefined value here causes illegal behavior
// :96:22: error: use of undefined value here causes illegal behavior
// :96:22: note: when computing vector element at index '0'
// :96:22: error: use of undefined value here causes illegal behavior
// :96:22: note: when computing vector element at index '0'
// :96:22: error: use of undefined value here causes illegal behavior
// :96:22: note: when computing vector element at index '1'
// :96:22: error: use of undefined value here causes illegal behavior
// :96:22: note: when computing vector element at index '0'
// :96:22: error: use of undefined value here causes illegal behavior
// :96:22: note: when computing vector element at index '0'
// :96:22: error: use of undefined value here causes illegal behavior
// :96:22: error: use of undefined value here causes illegal behavior
// :96:22: note: when computing vector element at index '0'
// :96:22: error: use of undefined value here causes illegal behavior
// :96:22: note: when computing vector element at index '0'
// :96:22: error: use of undefined value here causes illegal behavior
// :96:22: note: when computing vector element at index '1'
// :96:22: error: use of undefined value here causes illegal behavior
// :96:22: note: when computing vector element at index '0'
// :96:22: error: use of undefined value here causes illegal behavior
// :96:22: note: when computing vector element at index '0'
// :96:22: error: use of undefined value here causes illegal behavior
// :96:22: error: use of undefined value here causes illegal behavior
// :96:22: note: when computing vector element at index '0'
// :96:22: error: use of undefined value here causes illegal behavior
// :96:22: note: when computing vector element at index '0'
// :96:22: error: use of undefined value here causes illegal behavior
// :96:22: note: when computing vector element at index '1'
// :96:22: error: use of undefined value here causes illegal behavior
// :96:22: note: when computing vector element at index '0'
// :96:22: error: use of undefined value here causes illegal behavior
// :96:22: note: when computing vector element at index '0'
// :96:22: error: use of undefined value here causes illegal behavior
// :96:22: error: use of undefined value here causes illegal behavior
// :96:22: note: when computing vector element at index '0'
// :96:22: error: use of undefined value here causes illegal behavior
// :96:22: note: when computing vector element at index '0'
// :96:22: error: use of undefined value here causes illegal behavior
// :96:22: note: when computing vector element at index '1'
// :96:22: error: use of undefined value here causes illegal behavior
// :96:22: note: when computing vector element at index '0'
// :96:22: error: use of undefined value here causes illegal behavior
// :96:22: note: when computing vector element at index '0'
// :96:22: error: use of undefined value here causes illegal behavior
// :96:22: error: use of undefined value here causes illegal behavior
// :96:22: note: when computing vector element at index '0'
// :96:22: error: use of undefined value here causes illegal behavior
// :96:22: note: when computing vector element at index '0'
// :96:22: error: use of undefined value here causes illegal behavior
// :96:22: note: when computing vector element at index '1'
// :96:22: error: use of undefined value here causes illegal behavior
// :96:22: note: when computing vector element at index '0'
// :96:22: error: use of undefined value here causes illegal behavior
// :96:22: note: when computing vector element at index '0'
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: note: when computing vector element at index '0'
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: note: when computing vector element at index '0'
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: note: when computing vector element at index '0'
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: note: when computing vector element at index '1'
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: note: when computing vector element at index '0'
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: note: when computing vector element at index '0'
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: note: when computing vector element at index '0'
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: note: when computing vector element at index '0'
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: note: when computing vector element at index '0'
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: note: when computing vector element at index '0'
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: note: when computing vector element at index '1'
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: note: when computing vector element at index '0'
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: note: when computing vector element at index '0'
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: note: when computing vector element at index '0'
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: note: when computing vector element at index '0'
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: note: when computing vector element at index '0'
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: note: when computing vector element at index '0'
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: note: when computing vector element at index '1'
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: note: when computing vector element at index '0'
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: note: when computing vector element at index '0'
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: note: when computing vector element at index '0'
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: note: when computing vector element at index '0'
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: note: when computing vector element at index '0'
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: note: when computing vector element at index '0'
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: note: when computing vector element at index '1'
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: note: when computing vector element at index '0'
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: note: when computing vector element at index '0'
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: note: when computing vector element at index '0'
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: note: when computing vector element at index '0'
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: note: when computing vector element at index '0'
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: note: when computing vector element at index '0'
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: note: when computing vector element at index '1'
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: note: when computing vector element at index '0'
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: note: when computing vector element at index '0'
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: note: when computing vector element at index '0'
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: note: when computing vector element at index '0'
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: note: when computing vector element at index '0'
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: note: when computing vector element at index '0'
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: note: when computing vector element at index '1'
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: note: when computing vector element at index '0'
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: note: when computing vector element at index '0'
// :99:27: error: use of undefined value here causes illegal behavior
// :99:27: note: when computing vector element at index '0'
// :99:30: error: use of undefined value here causes illegal behavior
// :99:30: error: use of undefined value here causes illegal behavior
// :99:30: note: when computing vector element at index '0'
// :99:30: error: use of undefined value here causes illegal behavior
// :99:30: note: when computing vector element at index '0'
// :99:30: error: use of undefined value here causes illegal behavior
// :99:30: note: when computing vector element at index '1'
// :99:30: error: use of undefined value here causes illegal behavior
// :99:30: note: when computing vector element at index '0'
// :99:30: error: use of undefined value here causes illegal behavior
// :99:30: note: when computing vector element at index '0'
// :99:30: error: use of undefined value here causes illegal behavior
// :99:30: error: use of undefined value here causes illegal behavior
// :99:30: note: when computing vector element at index '0'
// :99:30: error: use of undefined value here causes illegal behavior
// :99:30: note: when computing vector element at index '0'
// :99:30: error: use of undefined value here causes illegal behavior
// :99:30: note: when computing vector element at index '1'
// :99:30: error: use of undefined value here causes illegal behavior
// :99:30: note: when computing vector element at index '0'
// :99:30: error: use of undefined value here causes illegal behavior
// :99:30: note: when computing vector element at index '0'
// :99:30: error: use of undefined value here causes illegal behavior
// :99:30: error: use of undefined value here causes illegal behavior
// :99:30: note: when computing vector element at index '0'
// :99:30: error: use of undefined value here causes illegal behavior
// :99:30: note: when computing vector element at index '0'
// :99:30: error: use of undefined value here causes illegal behavior
// :99:30: note: when computing vector element at index '1'
// :99:30: error: use of undefined value here causes illegal behavior
// :99:30: note: when computing vector element at index '0'
// :99:30: error: use of undefined value here causes illegal behavior
// :99:30: note: when computing vector element at index '0'
// :99:30: error: use of undefined value here causes illegal behavior
// :99:30: error: use of undefined value here causes illegal behavior
// :99:30: note: when computing vector element at index '0'
// :99:30: error: use of undefined value here causes illegal behavior
// :99:30: note: when computing vector element at index '0'
// :99:30: error: use of undefined value here causes illegal behavior
// :99:30: note: when computing vector element at index '1'
// :99:30: error: use of undefined value here causes illegal behavior
// :99:30: note: when computing vector element at index '0'
// :99:30: error: use of undefined value here causes illegal behavior
// :99:30: note: when computing vector element at index '0'
// :99:30: error: use of undefined value here causes illegal behavior
// :99:30: error: use of undefined value here causes illegal behavior
// :99:30: note: when computing vector element at index '0'
// :99:30: error: use of undefined value here causes illegal behavior
// :99:30: note: when computing vector element at index '0'
// :99:30: error: use of undefined value here causes illegal behavior
// :99:30: note: when computing vector element at index '1'
// :99:30: error: use of undefined value here causes illegal behavior
// :99:30: note: when computing vector element at index '0'
// :99:30: error: use of undefined value here causes illegal behavior
// :99:30: note: when computing vector element at index '0'
// :99:30: error: use of undefined value here causes illegal behavior
// :99:30: error: use of undefined value here causes illegal behavior
// :99:30: note: when computing vector element at index '0'
// :99:30: error: use of undefined value here causes illegal behavior
// :99:30: note: when computing vector element at index '0'
// :99:30: error: use of undefined value here causes illegal behavior
// :99:30: note: when computing vector element at index '1'
// :99:30: error: use of undefined value here causes illegal behavior
// :99:30: note: when computing vector element at index '0'
// :99:30: error: use of undefined value here causes illegal behavior
// :99:30: note: when computing vector element at index '0'
// :104:22: error: use of undefined value here causes illegal behavior
// :104:22: error: use of undefined value here causes illegal behavior
// :104:22: error: use of undefined value here causes illegal behavior
// :104:22: error: use of undefined value here causes illegal behavior
// :104:22: error: use of undefined value here causes illegal behavior
// :104:22: error: use of undefined value here causes illegal behavior
// :104:22: error: use of undefined value here causes illegal behavior
// :104:22: note: when computing vector element at index '1'
// :104:22: error: use of undefined value here causes illegal behavior
// :104:22: note: when computing vector element at index '1'
// :104:22: error: use of undefined value here causes illegal behavior
// :104:22: note: when computing vector element at index '1'
// :104:22: error: use of undefined value here causes illegal behavior
// :104:22: note: when computing vector element at index '1'
// :104:22: error: use of undefined value here causes illegal behavior
// :104:22: note: when computing vector element at index '0'
// :104:22: error: use of undefined value here causes illegal behavior
// :104:22: note: when computing vector element at index '0'
// :104:22: error: use of undefined value here causes illegal behavior
// :104:22: note: when computing vector element at index '0'
// :104:22: error: use of undefined value here causes illegal behavior
// :104:22: note: when computing vector element at index '0'
// :104:22: error: use of undefined value here causes illegal behavior
// :104:22: error: use of undefined value here causes illegal behavior
// :104:22: error: use of undefined value here causes illegal behavior
// :104:22: error: use of undefined value here causes illegal behavior
// :104:22: error: use of undefined value here causes illegal behavior
// :104:22: error: use of undefined value here causes illegal behavior
// :104:22: error: use of undefined value here causes illegal behavior
// :104:22: note: when computing vector element at index '1'
// :104:22: error: use of undefined value here causes illegal behavior
// :104:22: note: when computing vector element at index '1'
// :104:22: error: use of undefined value here causes illegal behavior
// :104:22: note: when computing vector element at index '1'
// :104:22: error: use of undefined value here causes illegal behavior
// :104:22: note: when computing vector element at index '1'
// :104:22: error: use of undefined value here causes illegal behavior
// :104:22: note: when computing vector element at index '0'
// :104:22: error: use of undefined value here causes illegal behavior
// :104:22: note: when computing vector element at index '0'
// :104:22: error: use of undefined value here causes illegal behavior
// :104:22: note: when computing vector element at index '0'
// :104:22: error: use of undefined value here causes illegal behavior
// :104:22: note: when computing vector element at index '0'
// :104:22: error: use of undefined value here causes illegal behavior
// :104:22: error: use of undefined value here causes illegal behavior
// :104:22: error: use of undefined value here causes illegal behavior
// :104:22: error: use of undefined value here causes illegal behavior
// :104:22: error: use of undefined value here causes illegal behavior
// :104:22: error: use of undefined value here causes illegal behavior
// :104:22: error: use of undefined value here causes illegal behavior
// :104:22: note: when computing vector element at index '1'
// :104:22: error: use of undefined value here causes illegal behavior
// :104:22: note: when computing vector element at index '1'
// :104:22: error: use of undefined value here causes illegal behavior
// :104:22: note: when computing vector element at index '1'
// :104:22: error: use of undefined value here causes illegal behavior
// :104:22: note: when computing vector element at index '1'
// :104:22: error: use of undefined value here causes illegal behavior
// :104:22: note: when computing vector element at index '0'
// :104:22: error: use of undefined value here causes illegal behavior
// :104:22: note: when computing vector element at index '0'
// :104:22: error: use of undefined value here causes illegal behavior
// :104:22: note: when computing vector element at index '0'
// :104:22: error: use of undefined value here causes illegal behavior
// :104:22: note: when computing vector element at index '0'
// :104:22: error: use of undefined value here causes illegal behavior
// :104:22: error: use of undefined value here causes illegal behavior
// :104:22: error: use of undefined value here causes illegal behavior
// :104:22: error: use of undefined value here causes illegal behavior
// :104:22: error: use of undefined value here causes illegal behavior
// :104:22: error: use of undefined value here causes illegal behavior
// :104:22: error: use of undefined value here causes illegal behavior
// :104:22: note: when computing vector element at index '1'
// :104:22: error: use of undefined value here causes illegal behavior
// :104:22: note: when computing vector element at index '1'
// :104:22: error: use of undefined value here causes illegal behavior
// :104:22: note: when computing vector element at index '1'
// :104:22: error: use of undefined value here causes illegal behavior
// :104:22: note: when computing vector element at index '1'
// :104:22: error: use of undefined value here causes illegal behavior
// :104:22: note: when computing vector element at index '0'
// :104:22: error: use of undefined value here causes illegal behavior
// :104:22: note: when computing vector element at index '0'
// :104:22: error: use of undefined value here causes illegal behavior
// :104:22: note: when computing vector element at index '0'
// :104:22: error: use of undefined value here causes illegal behavior
// :104:22: note: when computing vector element at index '0'
// :104:22: error: use of undefined value here causes illegal behavior
// :104:22: error: use of undefined value here causes illegal behavior
// :104:22: error: use of undefined value here causes illegal behavior
// :104:22: error: use of undefined value here causes illegal behavior
// :104:22: error: use of undefined value here causes illegal behavior
// :104:22: error: use of undefined value here causes illegal behavior
// :104:22: error: use of undefined value here causes illegal behavior
// :104:22: note: when computing vector element at index '1'
// :104:22: error: use of undefined value here causes illegal behavior
// :104:22: note: when computing vector element at index '1'
// :104:22: error: use of undefined value here causes illegal behavior
// :104:22: note: when computing vector element at index '1'
// :104:22: error: use of undefined value here causes illegal behavior
// :104:22: note: when computing vector element at index '1'
// :104:22: error: use of undefined value here causes illegal behavior
// :104:22: note: when computing vector element at index '0'
// :104:22: error: use of undefined value here causes illegal behavior
// :104:22: note: when computing vector element at index '0'
// :104:22: error: use of undefined value here causes illegal behavior
// :104:22: note: when computing vector element at index '0'
// :104:22: error: use of undefined value here causes illegal behavior
// :104:22: note: when computing vector element at index '0'
// :104:22: error: use of undefined value here causes illegal behavior
// :104:22: error: use of undefined value here causes illegal behavior
// :104:22: error: use of undefined value here causes illegal behavior
// :104:22: error: use of undefined value here causes illegal behavior
// :104:22: error: use of undefined value here causes illegal behavior
// :104:22: error: use of undefined value here causes illegal behavior
// :104:22: error: use of undefined value here causes illegal behavior
// :104:22: note: when computing vector element at index '1'
// :104:22: error: use of undefined value here causes illegal behavior
// :104:22: note: when computing vector element at index '1'
// :104:22: error: use of undefined value here causes illegal behavior
// :104:22: note: when computing vector element at index '1'
// :104:22: error: use of undefined value here causes illegal behavior
// :104:22: note: when computing vector element at index '1'
// :104:22: error: use of undefined value here causes illegal behavior
// :104:22: note: when computing vector element at index '0'
// :104:22: error: use of undefined value here causes illegal behavior
// :104:22: note: when computing vector element at index '0'
// :104:22: error: use of undefined value here causes illegal behavior
// :104:22: note: when computing vector element at index '0'
// :104:22: error: use of undefined value here causes illegal behavior
// :104:22: note: when computing vector element at index '0'
// :107:30: error: use of undefined value here causes illegal behavior
// :107:30: error: use of undefined value here causes illegal behavior
// :107:30: error: use of undefined value here causes illegal behavior
// :107:30: error: use of undefined value here causes illegal behavior
// :107:30: error: use of undefined value here causes illegal behavior
// :107:30: error: use of undefined value here causes illegal behavior
// :107:30: error: use of undefined value here causes illegal behavior
// :107:30: note: when computing vector element at index '1'
// :107:30: error: use of undefined value here causes illegal behavior
// :107:30: note: when computing vector element at index '1'
// :107:30: error: use of undefined value here causes illegal behavior
// :107:30: note: when computing vector element at index '1'
// :107:30: error: use of undefined value here causes illegal behavior
// :107:30: note: when computing vector element at index '1'
// :107:30: error: use of undefined value here causes illegal behavior
// :107:30: note: when computing vector element at index '0'
// :107:30: error: use of undefined value here causes illegal behavior
// :107:30: note: when computing vector element at index '0'
// :107:30: error: use of undefined value here causes illegal behavior
// :107:30: note: when computing vector element at index '0'
// :107:30: error: use of undefined value here causes illegal behavior
// :107:30: note: when computing vector element at index '0'
// :107:30: error: use of undefined value here causes illegal behavior
// :107:30: error: use of undefined value here causes illegal behavior
// :107:30: error: use of undefined value here causes illegal behavior
// :107:30: error: use of undefined value here causes illegal behavior
// :107:30: error: use of undefined value here causes illegal behavior
// :107:30: error: use of undefined value here causes illegal behavior
// :107:30: error: use of undefined value here causes illegal behavior
// :107:30: note: when computing vector element at index '1'
// :107:30: error: use of undefined value here causes illegal behavior
// :107:30: note: when computing vector element at index '1'
// :107:30: error: use of undefined value here causes illegal behavior
// :107:30: note: when computing vector element at index '1'
// :107:30: error: use of undefined value here causes illegal behavior
// :107:30: note: when computing vector element at index '1'
// :107:30: error: use of undefined value here causes illegal behavior
// :107:30: note: when computing vector element at index '0'
// :107:30: error: use of undefined value here causes illegal behavior
// :107:30: note: when computing vector element at index '0'
// :107:30: error: use of undefined value here causes illegal behavior
// :107:30: note: when computing vector element at index '0'
// :107:30: error: use of undefined value here causes illegal behavior
// :107:30: note: when computing vector element at index '0'
// :107:30: error: use of undefined value here causes illegal behavior
// :107:30: error: use of undefined value here causes illegal behavior
// :107:30: error: use of undefined value here causes illegal behavior
// :107:30: error: use of undefined value here causes illegal behavior
// :107:30: error: use of undefined value here causes illegal behavior
// :107:30: error: use of undefined value here causes illegal behavior
// :107:30: error: use of undefined value here causes illegal behavior
// :107:30: note: when computing vector element at index '1'
// :107:30: error: use of undefined value here causes illegal behavior
// :107:30: note: when computing vector element at index '1'
// :107:30: error: use of undefined value here causes illegal behavior
// :107:30: note: when computing vector element at index '1'
// :107:30: error: use of undefined value here causes illegal behavior
// :107:30: note: when computing vector element at index '1'
// :107:30: error: use of undefined value here causes illegal behavior
// :107:30: note: when computing vector element at index '0'
// :107:30: error: use of undefined value here causes illegal behavior
// :107:30: note: when computing vector element at index '0'
// :107:30: error: use of undefined value here causes illegal behavior
// :107:30: note: when computing vector element at index '0'
// :107:30: error: use of undefined value here causes illegal behavior
// :107:30: note: when computing vector element at index '0'
// :107:30: error: use of undefined value here causes illegal behavior
// :107:30: error: use of undefined value here causes illegal behavior
// :107:30: error: use of undefined value here causes illegal behavior
// :107:30: error: use of undefined value here causes illegal behavior
// :107:30: error: use of undefined value here causes illegal behavior
// :107:30: error: use of undefined value here causes illegal behavior
// :107:30: error: use of undefined value here causes illegal behavior
// :107:30: note: when computing vector element at index '1'
// :107:30: error: use of undefined value here causes illegal behavior
// :107:30: note: when computing vector element at index '1'
// :107:30: error: use of undefined value here causes illegal behavior
// :107:30: note: when computing vector element at index '1'
// :107:30: error: use of undefined value here causes illegal behavior
// :107:30: note: when computing vector element at index '1'
// :107:30: error: use of undefined value here causes illegal behavior
// :107:30: note: when computing vector element at index '0'
// :107:30: error: use of undefined value here causes illegal behavior
// :107:30: note: when computing vector element at index '0'
// :107:30: error: use of undefined value here causes illegal behavior
// :107:30: note: when computing vector element at index '0'
// :107:30: error: use of undefined value here causes illegal behavior
// :107:30: note: when computing vector element at index '0'
// :107:30: error: use of undefined value here causes illegal behavior
// :107:30: error: use of undefined value here causes illegal behavior
// :107:30: error: use of undefined value here causes illegal behavior
// :107:30: error: use of undefined value here causes illegal behavior
// :107:30: error: use of undefined value here causes illegal behavior
// :107:30: error: use of undefined value here causes illegal behavior
// :107:30: error: use of undefined value here causes illegal behavior
// :107:30: note: when computing vector element at index '1'
// :107:30: error: use of undefined value here causes illegal behavior
// :107:30: note: when computing vector element at index '1'
// :107:30: error: use of undefined value here causes illegal behavior
// :107:30: note: when computing vector element at index '1'
// :107:30: error: use of undefined value here causes illegal behavior
// :107:30: note: when computing vector element at index '1'
// :107:30: error: use of undefined value here causes illegal behavior
// :107:30: note: when computing vector element at index '0'
// :107:30: error: use of undefined value here causes illegal behavior
// :107:30: note: when computing vector element at index '0'
// :107:30: error: use of undefined value here causes illegal behavior
// :107:30: note: when computing vector element at index '0'
// :107:30: error: use of undefined value here causes illegal behavior
// :107:30: note: when computing vector element at index '0'
// :107:30: error: use of undefined value here causes illegal behavior
// :107:30: error: use of undefined value here causes illegal behavior
// :107:30: error: use of undefined value here causes illegal behavior
// :107:30: error: use of undefined value here causes illegal behavior
// :107:30: error: use of undefined value here causes illegal behavior
// :107:30: error: use of undefined value here causes illegal behavior
// :107:30: error: use of undefined value here causes illegal behavior
// :107:30: note: when computing vector element at index '1'
// :107:30: error: use of undefined value here causes illegal behavior
// :107:30: note: when computing vector element at index '1'
// :107:30: error: use of undefined value here causes illegal behavior
// :107:30: note: when computing vector element at index '1'
// :107:30: error: use of undefined value here causes illegal behavior
// :107:30: note: when computing vector element at index '1'
// :107:30: error: use of undefined value here causes illegal behavior
// :107:30: note: when computing vector element at index '0'
// :107:30: error: use of undefined value here causes illegal behavior
// :107:30: note: when computing vector element at index '0'
// :107:30: error: use of undefined value here causes illegal behavior
// :107:30: note: when computing vector element at index '0'
// :107:30: error: use of undefined value here causes illegal behavior
// :107:30: note: when computing vector element at index '0'
// :110:37: error: use of undefined value here causes illegal behavior
// :110:37: error: use of undefined value here causes illegal behavior
// :110:37: error: use of undefined value here causes illegal behavior
// :110:37: error: use of undefined value here causes illegal behavior
// :110:37: error: use of undefined value here causes illegal behavior
// :110:37: error: use of undefined value here causes illegal behavior
// :110:37: error: use of undefined value here causes illegal behavior
// :110:37: note: when computing vector element at index '1'
// :110:37: error: use of undefined value here causes illegal behavior
// :110:37: note: when computing vector element at index '1'
// :110:37: error: use of undefined value here causes illegal behavior
// :110:37: note: when computing vector element at index '1'
// :110:37: error: use of undefined value here causes illegal behavior
// :110:37: note: when computing vector element at index '1'
// :110:37: error: use of undefined value here causes illegal behavior
// :110:37: note: when computing vector element at index '0'
// :110:37: error: use of undefined value here causes illegal behavior
// :110:37: note: when computing vector element at index '0'
// :110:37: error: use of undefined value here causes illegal behavior
// :110:37: note: when computing vector element at index '0'
// :110:37: error: use of undefined value here causes illegal behavior
// :110:37: note: when computing vector element at index '0'
// :110:37: error: use of undefined value here causes illegal behavior
// :110:37: error: use of undefined value here causes illegal behavior
// :110:37: error: use of undefined value here causes illegal behavior
// :110:37: error: use of undefined value here causes illegal behavior
// :110:37: error: use of undefined value here causes illegal behavior
// :110:37: error: use of undefined value here causes illegal behavior
// :110:37: error: use of undefined value here causes illegal behavior
// :110:37: note: when computing vector element at index '1'
// :110:37: error: use of undefined value here causes illegal behavior
// :110:37: note: when computing vector element at index '1'
// :110:37: error: use of undefined value here causes illegal behavior
// :110:37: note: when computing vector element at index '1'
// :110:37: error: use of undefined value here causes illegal behavior
// :110:37: note: when computing vector element at index '1'
// :110:37: error: use of undefined value here causes illegal behavior
// :110:37: note: when computing vector element at index '0'
// :110:37: error: use of undefined value here causes illegal behavior
// :110:37: note: when computing vector element at index '0'
// :110:37: error: use of undefined value here causes illegal behavior
// :110:37: note: when computing vector element at index '0'
// :110:37: error: use of undefined value here causes illegal behavior
// :110:37: note: when computing vector element at index '0'
// :110:37: error: use of undefined value here causes illegal behavior
// :110:37: error: use of undefined value here causes illegal behavior
// :110:37: error: use of undefined value here causes illegal behavior
// :110:37: error: use of undefined value here causes illegal behavior
// :110:37: error: use of undefined value here causes illegal behavior
// :110:37: error: use of undefined value here causes illegal behavior
// :110:37: error: use of undefined value here causes illegal behavior
// :110:37: note: when computing vector element at index '1'
// :110:37: error: use of undefined value here causes illegal behavior
// :110:37: note: when computing vector element at index '1'
// :110:37: error: use of undefined value here causes illegal behavior
// :110:37: note: when computing vector element at index '1'
// :110:37: error: use of undefined value here causes illegal behavior
// :110:37: note: when computing vector element at index '1'
// :110:37: error: use of undefined value here causes illegal behavior
// :110:37: note: when computing vector element at index '0'
// :110:37: error: use of undefined value here causes illegal behavior
// :110:37: note: when computing vector element at index '0'
// :110:37: error: use of undefined value here causes illegal behavior
// :110:37: note: when computing vector element at index '0'
// :110:37: error: use of undefined value here causes illegal behavior
// :110:37: note: when computing vector element at index '0'
// :110:37: error: use of undefined value here causes illegal behavior
// :110:37: error: use of undefined value here causes illegal behavior
// :110:37: error: use of undefined value here causes illegal behavior
// :110:37: error: use of undefined value here causes illegal behavior
// :110:37: error: use of undefined value here causes illegal behavior
// :110:37: error: use of undefined value here causes illegal behavior
// :110:37: error: use of undefined value here causes illegal behavior
// :110:37: note: when computing vector element at index '1'
// :110:37: error: use of undefined value here causes illegal behavior
// :110:37: note: when computing vector element at index '1'
// :110:37: error: use of undefined value here causes illegal behavior
// :110:37: note: when computing vector element at index '1'
// :110:37: error: use of undefined value here causes illegal behavior
// :110:37: note: when computing vector element at index '1'
// :110:37: error: use of undefined value here causes illegal behavior
// :110:37: note: when computing vector element at index '0'
// :110:37: error: use of undefined value here causes illegal behavior
// :110:37: note: when computing vector element at index '0'
// :110:37: error: use of undefined value here causes illegal behavior
// :110:37: note: when computing vector element at index '0'
// :110:37: error: use of undefined value here causes illegal behavior
// :110:37: note: when computing vector element at index '0'
// :110:37: error: use of undefined value here causes illegal behavior
// :110:37: error: use of undefined value here causes illegal behavior
// :110:37: error: use of undefined value here causes illegal behavior
// :110:37: error: use of undefined value here causes illegal behavior
// :110:37: error: use of undefined value here causes illegal behavior
// :110:37: error: use of undefined value here causes illegal behavior
// :110:37: error: use of undefined value here causes illegal behavior
// :110:37: note: when computing vector element at index '1'
// :110:37: error: use of undefined value here causes illegal behavior
// :110:37: note: when computing vector element at index '1'
// :110:37: error: use of undefined value here causes illegal behavior
// :110:37: note: when computing vector element at index '1'
// :110:37: error: use of undefined value here causes illegal behavior
// :110:37: note: when computing vector element at index '1'
// :110:37: error: use of undefined value here causes illegal behavior
// :110:37: note: when computing vector element at index '0'
// :110:37: error: use of undefined value here causes illegal behavior
// :110:37: note: when computing vector element at index '0'
// :110:37: error: use of undefined value here causes illegal behavior
// :110:37: note: when computing vector element at index '0'
// :110:37: error: use of undefined value here causes illegal behavior
// :110:37: note: when computing vector element at index '0'
// :110:37: error: use of undefined value here causes illegal behavior
// :110:37: error: use of undefined value here causes illegal behavior
// :110:37: error: use of undefined value here causes illegal behavior
// :110:37: error: use of undefined value here causes illegal behavior
// :110:37: error: use of undefined value here causes illegal behavior
// :110:37: error: use of undefined value here causes illegal behavior
// :110:37: error: use of undefined value here causes illegal behavior
// :110:37: note: when computing vector element at index '1'
// :110:37: error: use of undefined value here causes illegal behavior
// :110:37: note: when computing vector element at index '1'
// :110:37: error: use of undefined value here causes illegal behavior
// :110:37: note: when computing vector element at index '1'
// :110:37: error: use of undefined value here causes illegal behavior
// :110:37: note: when computing vector element at index '1'
// :110:37: error: use of undefined value here causes illegal behavior
// :110:37: note: when computing vector element at index '0'
// :110:37: error: use of undefined value here causes illegal behavior
// :110:37: note: when computing vector element at index '0'
// :110:37: error: use of undefined value here causes illegal behavior
// :110:37: note: when computing vector element at index '0'
// :110:37: error: use of undefined value here causes illegal behavior
// :110:37: note: when computing vector element at index '0'
// :113:22: error: use of undefined value here causes illegal behavior
// :113:22: error: use of undefined value here causes illegal behavior
// :113:22: error: use of undefined value here causes illegal behavior
// :113:22: error: use of undefined value here causes illegal behavior
// :113:22: error: use of undefined value here causes illegal behavior
// :113:22: error: use of undefined value here causes illegal behavior
// :113:22: error: use of undefined value here causes illegal behavior
// :113:22: note: when computing vector element at index '1'
// :113:22: error: use of undefined value here causes illegal behavior
// :113:22: note: when computing vector element at index '1'
// :113:22: error: use of undefined value here causes illegal behavior
// :113:22: note: when computing vector element at index '1'
// :113:22: error: use of undefined value here causes illegal behavior
// :113:22: note: when computing vector element at index '1'
// :113:22: error: use of undefined value here causes illegal behavior
// :113:22: note: when computing vector element at index '0'
// :113:22: error: use of undefined value here causes illegal behavior
// :113:22: note: when computing vector element at index '0'
// :113:22: error: use of undefined value here causes illegal behavior
// :113:22: note: when computing vector element at index '0'
// :113:22: error: use of undefined value here causes illegal behavior
// :113:22: note: when computing vector element at index '0'
// :113:22: error: use of undefined value here causes illegal behavior
// :113:22: error: use of undefined value here causes illegal behavior
// :113:22: error: use of undefined value here causes illegal behavior
// :113:22: error: use of undefined value here causes illegal behavior
// :113:22: error: use of undefined value here causes illegal behavior
// :113:22: error: use of undefined value here causes illegal behavior
// :113:22: error: use of undefined value here causes illegal behavior
// :113:22: note: when computing vector element at index '1'
// :113:22: error: use of undefined value here causes illegal behavior
// :113:22: note: when computing vector element at index '1'
// :113:22: error: use of undefined value here causes illegal behavior
// :113:22: note: when computing vector element at index '1'
// :113:22: error: use of undefined value here causes illegal behavior
// :113:22: note: when computing vector element at index '1'
// :113:22: error: use of undefined value here causes illegal behavior
// :113:22: note: when computing vector element at index '0'
// :113:22: error: use of undefined value here causes illegal behavior
// :113:22: note: when computing vector element at index '0'
// :113:22: error: use of undefined value here causes illegal behavior
// :113:22: note: when computing vector element at index '0'
// :113:22: error: use of undefined value here causes illegal behavior
// :113:22: note: when computing vector element at index '0'
// :113:22: error: use of undefined value here causes illegal behavior
// :113:22: error: use of undefined value here causes illegal behavior
// :113:22: error: use of undefined value here causes illegal behavior
// :113:22: error: use of undefined value here causes illegal behavior
// :113:22: error: use of undefined value here causes illegal behavior
// :113:22: error: use of undefined value here causes illegal behavior
// :113:22: error: use of undefined value here causes illegal behavior
// :113:22: note: when computing vector element at index '1'
// :113:22: error: use of undefined value here causes illegal behavior
// :113:22: note: when computing vector element at index '1'
// :113:22: error: use of undefined value here causes illegal behavior
// :113:22: note: when computing vector element at index '1'
// :113:22: error: use of undefined value here causes illegal behavior
// :113:22: note: when computing vector element at index '1'
// :113:22: error: use of undefined value here causes illegal behavior
// :113:22: note: when computing vector element at index '0'
// :113:22: error: use of undefined value here causes illegal behavior
// :113:22: note: when computing vector element at index '0'
// :113:22: error: use of undefined value here causes illegal behavior
// :113:22: note: when computing vector element at index '0'
// :113:22: error: use of undefined value here causes illegal behavior
// :113:22: note: when computing vector element at index '0'
// :113:22: error: use of undefined value here causes illegal behavior
// :113:22: error: use of undefined value here causes illegal behavior
// :113:22: error: use of undefined value here causes illegal behavior
// :113:22: error: use of undefined value here causes illegal behavior
// :113:22: error: use of undefined value here causes illegal behavior
// :113:22: error: use of undefined value here causes illegal behavior
// :113:22: error: use of undefined value here causes illegal behavior
// :113:22: note: when computing vector element at index '1'
// :113:22: error: use of undefined value here causes illegal behavior
// :113:22: note: when computing vector element at index '1'
// :113:22: error: use of undefined value here causes illegal behavior
// :113:22: note: when computing vector element at index '1'
// :113:22: error: use of undefined value here causes illegal behavior
// :113:22: note: when computing vector element at index '1'
// :113:22: error: use of undefined value here causes illegal behavior
// :113:22: note: when computing vector element at index '0'
// :113:22: error: use of undefined value here causes illegal behavior
// :113:22: note: when computing vector element at index '0'
// :113:22: error: use of undefined value here causes illegal behavior
// :113:22: note: when computing vector element at index '0'
// :113:22: error: use of undefined value here causes illegal behavior
// :113:22: note: when computing vector element at index '0'
// :113:22: error: use of undefined value here causes illegal behavior
// :113:22: error: use of undefined value here causes illegal behavior
// :113:22: error: use of undefined value here causes illegal behavior
// :113:22: error: use of undefined value here causes illegal behavior
// :113:22: error: use of undefined value here causes illegal behavior
// :113:22: error: use of undefined value here causes illegal behavior
// :113:22: error: use of undefined value here causes illegal behavior
// :113:22: note: when computing vector element at index '1'
// :113:22: error: use of undefined value here causes illegal behavior
// :113:22: note: when computing vector element at index '1'
// :113:22: error: use of undefined value here causes illegal behavior
// :113:22: note: when computing vector element at index '1'
// :113:22: error: use of undefined value here causes illegal behavior
// :113:22: note: when computing vector element at index '1'
// :113:22: error: use of undefined value here causes illegal behavior
// :113:22: note: when computing vector element at index '0'
// :113:22: error: use of undefined value here causes illegal behavior
// :113:22: note: when computing vector element at index '0'
// :113:22: error: use of undefined value here causes illegal behavior
// :113:22: note: when computing vector element at index '0'
// :113:22: error: use of undefined value here causes illegal behavior
// :113:22: note: when computing vector element at index '0'
// :113:22: error: use of undefined value here causes illegal behavior
// :113:22: error: use of undefined value here causes illegal behavior
// :113:22: error: use of undefined value here causes illegal behavior
// :113:22: error: use of undefined value here causes illegal behavior
// :113:22: error: use of undefined value here causes illegal behavior
// :113:22: error: use of undefined value here causes illegal behavior
// :113:22: error: use of undefined value here causes illegal behavior
// :113:22: note: when computing vector element at index '1'
// :113:22: error: use of undefined value here causes illegal behavior
// :113:22: note: when computing vector element at index '1'
// :113:22: error: use of undefined value here causes illegal behavior
// :113:22: note: when computing vector element at index '1'
// :113:22: error: use of undefined value here causes illegal behavior
// :113:22: note: when computing vector element at index '1'
// :113:22: error: use of undefined value here causes illegal behavior
// :113:22: note: when computing vector element at index '0'
// :113:22: error: use of undefined value here causes illegal behavior
// :113:22: note: when computing vector element at index '0'
// :113:22: error: use of undefined value here causes illegal behavior
// :113:22: note: when computing vector element at index '0'
// :113:22: error: use of undefined value here causes illegal behavior
// :113:22: note: when computing vector element at index '0'
// :116:30: error: use of undefined value here causes illegal behavior
// :116:30: error: use of undefined value here causes illegal behavior
// :116:30: error: use of undefined value here causes illegal behavior
// :116:30: error: use of undefined value here causes illegal behavior
// :116:30: error: use of undefined value here causes illegal behavior
// :116:30: error: use of undefined value here causes illegal behavior
// :116:30: error: use of undefined value here causes illegal behavior
// :116:30: note: when computing vector element at index '1'
// :116:30: error: use of undefined value here causes illegal behavior
// :116:30: note: when computing vector element at index '1'
// :116:30: error: use of undefined value here causes illegal behavior
// :116:30: note: when computing vector element at index '1'
// :116:30: error: use of undefined value here causes illegal behavior
// :116:30: note: when computing vector element at index '1'
// :116:30: error: use of undefined value here causes illegal behavior
// :116:30: note: when computing vector element at index '0'
// :116:30: error: use of undefined value here causes illegal behavior
// :116:30: note: when computing vector element at index '0'
// :116:30: error: use of undefined value here causes illegal behavior
// :116:30: note: when computing vector element at index '0'
// :116:30: error: use of undefined value here causes illegal behavior
// :116:30: note: when computing vector element at index '0'
// :116:30: error: use of undefined value here causes illegal behavior
// :116:30: error: use of undefined value here causes illegal behavior
// :116:30: error: use of undefined value here causes illegal behavior
// :116:30: error: use of undefined value here causes illegal behavior
// :116:30: error: use of undefined value here causes illegal behavior
// :116:30: error: use of undefined value here causes illegal behavior
// :116:30: error: use of undefined value here causes illegal behavior
// :116:30: note: when computing vector element at index '1'
// :116:30: error: use of undefined value here causes illegal behavior
// :116:30: note: when computing vector element at index '1'
// :116:30: error: use of undefined value here causes illegal behavior
// :116:30: note: when computing vector element at index '1'
// :116:30: error: use of undefined value here causes illegal behavior
// :116:30: note: when computing vector element at index '1'
// :116:30: error: use of undefined value here causes illegal behavior
// :116:30: note: when computing vector element at index '0'
// :116:30: error: use of undefined value here causes illegal behavior
// :116:30: note: when computing vector element at index '0'
// :116:30: error: use of undefined value here causes illegal behavior
// :116:30: note: when computing vector element at index '0'
// :116:30: error: use of undefined value here causes illegal behavior
// :116:30: note: when computing vector element at index '0'
// :116:30: error: use of undefined value here causes illegal behavior
// :116:30: error: use of undefined value here causes illegal behavior
// :116:30: error: use of undefined value here causes illegal behavior
// :116:30: error: use of undefined value here causes illegal behavior
// :116:30: error: use of undefined value here causes illegal behavior
// :116:30: error: use of undefined value here causes illegal behavior
// :116:30: error: use of undefined value here causes illegal behavior
// :116:30: note: when computing vector element at index '1'
// :116:30: error: use of undefined value here causes illegal behavior
// :116:30: note: when computing vector element at index '1'
// :116:30: error: use of undefined value here causes illegal behavior
// :116:30: note: when computing vector element at index '1'
// :116:30: error: use of undefined value here causes illegal behavior
// :116:30: note: when computing vector element at index '1'
// :116:30: error: use of undefined value here causes illegal behavior
// :116:30: note: when computing vector element at index '0'
// :116:30: error: use of undefined value here causes illegal behavior
// :116:30: note: when computing vector element at index '0'
// :116:30: error: use of undefined value here causes illegal behavior
// :116:30: note: when computing vector element at index '0'
// :116:30: error: use of undefined value here causes illegal behavior
// :116:30: note: when computing vector element at index '0'
// :116:30: error: use of undefined value here causes illegal behavior
// :116:30: error: use of undefined value here causes illegal behavior
// :116:30: error: use of undefined value here causes illegal behavior
// :116:30: error: use of undefined value here causes illegal behavior
// :116:30: error: use of undefined value here causes illegal behavior
// :116:30: error: use of undefined value here causes illegal behavior
// :116:30: error: use of undefined value here causes illegal behavior
// :116:30: note: when computing vector element at index '1'
// :116:30: error: use of undefined value here causes illegal behavior
// :116:30: note: when computing vector element at index '1'
// :116:30: error: use of undefined value here causes illegal behavior
// :116:30: note: when computing vector element at index '1'
// :116:30: error: use of undefined value here causes illegal behavior
// :116:30: note: when computing vector element at index '1'
// :116:30: error: use of undefined value here causes illegal behavior
// :116:30: note: when computing vector element at index '0'
// :116:30: error: use of undefined value here causes illegal behavior
// :116:30: note: when computing vector element at index '0'
// :116:30: error: use of undefined value here causes illegal behavior
// :116:30: note: when computing vector element at index '0'
// :116:30: error: use of undefined value here causes illegal behavior
// :116:30: note: when computing vector element at index '0'
// :116:30: error: use of undefined value here causes illegal behavior
// :116:30: error: use of undefined value here causes illegal behavior
// :116:30: error: use of undefined value here causes illegal behavior
// :116:30: error: use of undefined value here causes illegal behavior
// :116:30: error: use of undefined value here causes illegal behavior
// :116:30: error: use of undefined value here causes illegal behavior
// :116:30: error: use of undefined value here causes illegal behavior
// :116:30: note: when computing vector element at index '1'
// :116:30: error: use of undefined value here causes illegal behavior
// :116:30: note: when computing vector element at index '1'
// :116:30: error: use of undefined value here causes illegal behavior
// :116:30: note: when computing vector element at index '1'
// :116:30: error: use of undefined value here causes illegal behavior
// :116:30: note: when computing vector element at index '1'
// :116:30: error: use of undefined value here causes illegal behavior
// :116:30: note: when computing vector element at index '0'
// :116:30: error: use of undefined value here causes illegal behavior
// :116:30: note: when computing vector element at index '0'
// :116:30: error: use of undefined value here causes illegal behavior
// :116:30: note: when computing vector element at index '0'
// :116:30: error: use of undefined value here causes illegal behavior
// :116:30: note: when computing vector element at index '0'
// :116:30: error: use of undefined value here causes illegal behavior
// :116:30: error: use of undefined value here causes illegal behavior
// :116:30: error: use of undefined value here causes illegal behavior
// :116:30: error: use of undefined value here causes illegal behavior
// :116:30: error: use of undefined value here causes illegal behavior
// :116:30: error: use of undefined value here causes illegal behavior
// :116:30: error: use of undefined value here causes illegal behavior
// :116:30: note: when computing vector element at index '1'
// :116:30: error: use of undefined value here causes illegal behavior
// :116:30: note: when computing vector element at index '1'
// :116:30: error: use of undefined value here causes illegal behavior
// :116:30: note: when computing vector element at index '1'
// :116:30: error: use of undefined value here causes illegal behavior
// :116:30: note: when computing vector element at index '1'
// :116:30: error: use of undefined value here causes illegal behavior
// :116:30: note: when computing vector element at index '0'
// :116:30: error: use of undefined value here causes illegal behavior
// :116:30: note: when computing vector element at index '0'
// :116:30: error: use of undefined value here causes illegal behavior
// :116:30: note: when computing vector element at index '0'
// :116:30: error: use of undefined value here causes illegal behavior
// :116:30: note: when computing vector element at index '0'

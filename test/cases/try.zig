const assert = @import("std").debug.assert;

test "try on error union" {
    tryOnErrorUnionImpl();
    comptime tryOnErrorUnionImpl();
}

fn tryOnErrorUnionImpl() void {
    const x = if (returnsTen()) |val| val + 1 else |err| switch (err) {
        error.ItBroke, error.NoMem => 1,
        error.CrappedOut => i32(2),
        else => unreachable,
    };
    assert(x == 11);
}

fn returnsTen() error!i32 {
    return 10;
}

test "try without vars" {
    const result1 = if (failIfTrue(true)) 1 else |_| i32(2);
    assert(result1 == 2);

    const result2 = if (failIfTrue(false)) 1 else |_| i32(2);
    assert(result2 == 1);
}

fn failIfTrue(ok: bool) error!void {
    if (ok) {
        return error.ItBroke;
    } else {
        return;
    }
}

test "try then not executed with assignment" {
    if (failIfTrue(true)) {
        unreachable;
    } else |err| {
        assert(err == error.ItBroke);
    }
}

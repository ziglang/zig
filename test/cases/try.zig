const assertOrPanic = @import("std").debug.assertOrPanic;

test "try without vars" {
    const result1 = if (failIfTrue(true)) 1 else |_| i32(2);
    assertOrPanic(result1 == 2);

    const result2 = if (failIfTrue(false)) 1 else |_| i32(2);
    assertOrPanic(result2 == 1);
}

fn failIfTrue(ok: bool) anyerror!void {
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
        assertOrPanic(err == error.ItBroke);
    }
}

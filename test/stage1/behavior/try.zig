const assertOrPanic = @import("std").debug.assertOrPanic;

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
    assertOrPanic(x == 11);
}

fn returnsTen() anyerror!i32 {
    return 10;
}

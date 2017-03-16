const assert = @import("std").debug.assert;

test "tryOnErrorUnion" {
    tryOnErrorUnionImpl();
    comptime tryOnErrorUnionImpl();

}

fn tryOnErrorUnionImpl() {
    const x = try (const val = returnsTen()) {
        val + 1
    } else |err| switch (err) {
        error.ItBroke, error.NoMem => 1,
        error.CrappedOut => i32(2),
    };
    assert(x == 11);
}

error ItBroke;
error NoMem;
error CrappedOut;
fn returnsTen() -> %i32 {
    10
}

test "tryWithoutVars" {
    const result1 = try (failIfTrue(true)) {
        1
    } else {
        i32(2)
    };
    assert(result1 == 2);

    const result2 = try (failIfTrue(false)) {
        1
    } else {
        i32(2)
    };
    assert(result2 == 1);
}

fn failIfTrue(ok: bool) -> %void {
    if (ok) {
        return error.ItBroke;
    } else {
        return;
    }
}

// TODO
//fn tryThenNotExecutedWithAssignment() {
//    @setFnTest(this);
//
//    try (_ = failIfTrue(true)) {
//        @unreachable();
//    } else |err| {
//        assert(err == error.ItBroke);
//    }
//}

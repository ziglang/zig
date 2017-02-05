const assert = @import("std").debug.assert;

fn tryOnErrorUnion() {
    @setFnTest(this);

    const x = try (const val = returnsTen()) {
        val + 1
    } else |err| switch (err) {
        error.ItBroke, error.NoMem => 1,
        error.CrappedOut => i32(2),
    };
    assert(x == 11);
}

fn tryOnErrorUnionComptime() {
    @setFnTest(this);

    comptime {
        const x = try (const val = returnsTen()) {
            val + 1
        } else |err| switch (err) {
            error.ItBroke, error.NoMem => 1,
            error.CrappedOut => i32(2),
        };
        assert(x == 11);
    }
}
error ItBroke;
error NoMem;
error CrappedOut;
fn returnsTen() -> %i32 {
    10
}

fn tryWithoutVars() {
    @setFnTest(this);

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

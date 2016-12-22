fn nullableType() {
    @setFnTest(this);

    const x : ?bool = true;

    if (const y ?= x) {
        if (y) {
            // OK
        } else {
            @unreachable();
        }
    } else {
        @unreachable();
    }

    const next_x : ?i32 = null;

    const z = next_x ?? 1234;

    assert(z == 1234);

    const final_x : ?i32 = 13;

    const num = final_x ?? @unreachable();

    assert(num == 13);
}

fn assignToIfVarPtr() {
    @setFnTest(this);

    var maybe_bool: ?bool = true;

    if (const *b ?= maybe_bool) {
        *b = false;
    }

    assert(??maybe_bool == false);
}


// TODO const assert = @import("std").debug.assert;
fn assert(ok: bool) {
    if (!ok)
        @unreachable();
}


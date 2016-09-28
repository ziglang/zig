const assert = @import("std").debug.assert;

var read_count: u64 = 0;

fn readOnce() -> %u64 {
    read_count += 1;
    return read_count;
}

error InvalidDebugInfo;

enum FormValue {
    Address: u64,
    Other: bool,
}

fn doThing(form_id: u64) -> %FormValue {
    @setFnStaticEval(this, false);

    return switch (form_id) {
        17 => FormValue.Address { %return readOnce() },
        else => error.InvalidDebugInfo,
    }
}

fn switchProngReturnsErrorEnum() {
    @setFnTest(this, true);

    %%doThing(17);
    assert(read_count == 1);
}

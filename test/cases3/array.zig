fn arrays() {
    @setFnTest(this);

    var array : [5]u32 = undefined;

    var i : u32 = 0;
    while (i < 5) {
        array[i] = i + 1;
        i = array[i];
    }

    i = 0;
    var accumulator = u32(0);
    while (i < 5) {
        accumulator += array[i];

        i += 1;
    }

    assert(accumulator == 15);
    assert(getArrayLen(array) == 5);
}
fn getArrayLen(a: []u32) -> usize {
    a.len
}

// TODO const assert = @import("std").debug.assert;
fn assert(ok: bool) {
    if (!ok)
        @unreachable();
}

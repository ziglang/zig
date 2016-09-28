const assert = @import("std").debug.assert;

fn maxValueType() {
    @setFnTest(this, true);

    // If the type of @maxValue(i32) was i32 then this implicit cast to
    // u32 would not work. But since the value is a number literal,
    // it works fine.
    const x: u32 = @maxValue(i32);
    assert(x == 2147483647);
}

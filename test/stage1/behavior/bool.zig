const assertOrPanic = @import("std").debug.assertOrPanic;

test "bool literals" {
    assertOrPanic(true);
    assertOrPanic(!false);
}

test "cast bool to int" {
    const t = true;
    const f = false;
    assertOrPanic(@boolToInt(t) == u32(1));
    assertOrPanic(@boolToInt(f) == u32(0));
    nonConstCastBoolToInt(t, f);
}

fn nonConstCastBoolToInt(t: bool, f: bool) void {
    assertOrPanic(@boolToInt(t) == u32(1));
    assertOrPanic(@boolToInt(f) == u32(0));
}

test "bool cmp" {
    assertOrPanic(testBoolCmp(true, false) == false);
}
fn testBoolCmp(a: bool, b: bool) bool {
    return a == b;
}

const global_f = false;
const global_t = true;
const not_global_f = !global_f;
const not_global_t = !global_t;
test "compile time bool not" {
    assertOrPanic(not_global_f);
    assertOrPanic(!not_global_t);
}

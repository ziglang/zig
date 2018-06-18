const assert = @import("std").debug.assert;

test "bool literals" {
    assert(true);
    assert(!false);
}

test "cast bool to int" {
    const t = true;
    const f = false;
    assert(@boolToInt(t) == u32(1));
    assert(@boolToInt(f) == u32(0));
    nonConstCastBoolToInt(t, f);
}

fn nonConstCastBoolToInt(t: bool, f: bool) void {
    assert(@boolToInt(t) == u32(1));
    assert(@boolToInt(f) == u32(0));
}

test "bool cmp" {
    assert(testBoolCmp(true, false) == false);
}
fn testBoolCmp(a: bool, b: bool) bool {
    return a == b;
}

const global_f = false;
const global_t = true;
const not_global_f = !global_f;
const not_global_t = !global_t;
test "compile time bool not" {
    assert(not_global_f);
    assert(!not_global_t);
}

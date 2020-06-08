const expect = @import("std").testing.expect;

test "bool literals" {
    expect(true);
    expect(!false);
}

test "cast bool to int" {
    const t = true;
    const f = false;
    expect(@boolToInt(t) == @as(u32, 1));
    expect(@boolToInt(f) == @as(u32, 0));
    nonConstCastBoolToInt(t, f);
}

fn nonConstCastBoolToInt(t: bool, f: bool) void {
    expect(@boolToInt(t) == @as(u32, 1));
    expect(@boolToInt(f) == @as(u32, 0));
}

test "bool cmp" {
    expect(testBoolCmp(true, false) == false);
}
fn testBoolCmp(a: bool, b: bool) bool {
    return a == b;
}

const global_f = false;
const global_t = true;
const not_global_f = !global_f;
const not_global_t = !global_t;
test "compile time bool not" {
    expect(not_global_f);
    expect(!not_global_t);
}

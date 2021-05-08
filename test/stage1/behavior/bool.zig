const expect = @import("std").testing.expect;

test "bool literals" {
    try expect(true);
    try expect(!false);
}

test "cast bool to int" {
    const t = true;
    const f = false;
    try expect(@boolToInt(t) == @as(u32, 1));
    try expect(@boolToInt(f) == @as(u32, 0));
    try nonConstCastBoolToInt(t, f);
}

fn nonConstCastBoolToInt(t: bool, f: bool) !void {
    try expect(@boolToInt(t) == @as(u32, 1));
    try expect(@boolToInt(f) == @as(u32, 0));
}

test "bool cmp" {
    try expect(testBoolCmp(true, false) == false);
}
fn testBoolCmp(a: bool, b: bool) bool {
    return a == b;
}

const global_f = false;
const global_t = true;
const not_global_f = !global_f;
const not_global_t = !global_t;
test "compile time bool not" {
    try expect(not_global_f);
    try expect(!not_global_t);
}

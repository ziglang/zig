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

test "bool vectors" {
    const S = struct {
        fn doTheTest() void {
            var b: @Vector(4, bool) = [_]bool{true, false, true, false};
            var i: @Vector(4, u1) = @boolToInt(b);
            expect(i[0] == 1);
            expect(i[1] == 0);
            expect(i[2] == 1);
            expect(i[3] == 0);
        }
    };
    S.doTheTest();
    comptime S.doTheTest();
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

test "bool branching ordering" {
    const S = struct {
        fn doTheTest() void {
            var o = false;
            var t = true;
            var f = false;
            _ = t or wasRun(&o);
            expect(o == false);
            _ = f and wasRun(&o);
            expect(o == false);
            _ = t | wasRun(&o);
            expect(o == true);
            o = false;
            _ = f & wasRun(&o);
            expect(o == true);
        }
    };
    S.doTheTest();
    comptime S.doTheTest();
}

fn wasRun(b: *bool) bool {
    b.* = true;
    return true;
}

const assert = @import("std").debug.assert;

fn boolLiterals() {
    @setFnTest(this);

    assert(true);
    assert(!false);
}

fn castBoolToInt() {
    @setFnTest(this);

    const t = true;
    const f = false;
    assert(i32(t) == i32(1));
    assert(i32(f) == i32(0));
    nonConstCastBoolToInt(t, f);
}

fn nonConstCastBoolToInt(t: bool, f: bool) {
    assert(i32(t) == i32(1));
    assert(i32(f) == i32(0));
}

fn boolCmp() {
    @setFnTest(this);

    assert(testBoolCmp(true, false) == false);
}
fn testBoolCmp(a: bool, b: bool) -> bool {
    a == b
}

fn shortCircuitAndOr() {
    @setFnTest(this);

    var a = true;
    a &&= false;
    assert(!a);
    a &&= true;
    assert(!a);
    a ||= false;
    assert(!a);
    a ||= true;
    assert(a);
}

const global_f = false;
const global_t = true;
const not_global_f = !global_f;
const not_global_t = !global_t;
fn compileTimeBoolnot() {
    @setFnTest(this);

    assert(not_global_f);
    assert(!not_global_t);
}

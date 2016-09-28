const assert = @import("std").debug.assert;

fn varParams() {
    @setFnTest(this, true);

    assert(max_i32(12, 34) == 34);
    assert(max_f64(1.2, 3.4) == 3.4);

    assert(max_i32_noeval(12, 34) == 34);
    assert(max_f64_noeval(1.2, 3.4) == 3.4);
}

fn max(a: var, b: var) -> @typeOf(a) {
    if (a > b) a else b
}

fn max_i32(a: i32, b: i32) -> i32 {
    max(a, b)
}

fn max_f64(a: f64, b: f64) -> f64 {
    max(a, b)
}

fn max_i32_noeval(a: i32, b: i32) -> i32 {
    @setFnStaticEval(this, false);

    max(a, b)
}

fn max_f64_noeval(a: f64, b: f64) -> f64 {
    @setFnStaticEval(this, false);

    max(a, b)
}

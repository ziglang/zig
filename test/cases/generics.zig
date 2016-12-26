fn simpleGenericFn() {
    @setFnTest(this);

    assert(max(i32, 3, -1) == 3);
    assert(max(f32, 0.123, 0.456) == 0.456);
    assert(add(2, 3) == 5);
}

fn max(inline T: type, a: T, b: T) -> T {
    return if (a > b) a else b;
}

fn add(inline a: i32, b: i32) -> i32 {
    return @staticEval(a) + b;
}

const the_max = max(u32, 1234, 5678);
fn compileTimeGenericEval() {
    @setFnTest(this);
    assert(the_max == 5678);
}

fn gimmeTheBigOne(a: u32, b: u32) -> u32 {
    max(u32, a, b)
}

fn shouldCallSameInstance(a: u32, b: u32) -> u32 {
    max(u32, a, b)
}

fn sameButWithFloats(a: f64, b: f64) -> f64 {
    max(f64, a, b)
}

fn fnWithInlineArgs() {
    @setFnTest(this);

    assert(gimmeTheBigOne(1234, 5678) == 5678);
    assert(shouldCallSameInstance(34, 12) == 34);
    assert(sameButWithFloats(0.43, 0.49) == 0.49);
}


fn varParams() {
    @setFnTest(this);

    assert(max_i32(12, 34) == 34);
    assert(max_f64(1.2, 3.4) == 3.4);
}

// TODO `_`
const _1 = assert(max_i32(12, 34) == 34);
const _2 = assert(max_f64(1.2, 3.4) == 3.4);

fn max_var(a: var, b: var) -> @typeOf(a + b) {
    if (a > b) a else b
}

fn max_i32(a: i32, b: i32) -> i32 {
    max_var(a, b)
}

fn max_f64(a: f64, b: f64) -> f64 {
    max_var(a, b)
}


pub fn List(inline T: type) -> type {
    SmallList(T, 8)
}

pub fn SmallList(inline T: type, inline STATIC_SIZE: usize) -> type {
    struct {
        items: []T,
        length: usize,
        prealloc_items: [STATIC_SIZE]T,
    }
}

fn functionWithReturnTypeType() {
    @setFnTest(this);

    var list: List(i32) = undefined;
    var list2: List(i32) = undefined;
    list.length = 10;
    list2.length = 10;
    assert(list.prealloc_items.len == 8);
    assert(list2.prealloc_items.len == 8);
}

// TODO const assert = @import("std").debug.assert;
fn assert(ok: bool) {
    if (!ok)
        @unreachable();
}


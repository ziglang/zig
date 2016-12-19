const case_namespace_fn_call = @import("cases/namespace_fn_call.zig");


fn testNamespaceFnCall() {
    assert(case_namespace_fn_call.foo() == 1234);
}


const FooA = struct {
    fn add(a: i32, b: i32) -> i32 { a + b }
};
const foo_a = FooA {};

fn testStructStatic() {
    const result = FooA.add(3, 4);
    assert(result == 7);
}

const should_be_11 = FooA.add(5, 6);
fn testStaticFnEval() {
    assert(should_be_11 == 11);
}

fn fib(x: i32) -> i32 {
    if (x < 2) x else fib(x - 1) + fib(x - 2)
}

const fib_7 = fib(7);

fn testCompileTimeFib() {
    assert(fib_7 == 13);
}

fn unwrapAndAddOne(blah: ?i32) -> i32 {
    return ??blah + 1;
}

const should_be_1235 = unwrapAndAddOne(1234);

fn testStaticAddOne() {
    assert(should_be_1235 == 1235);
}

fn gimme1or2(inline a: bool) -> i32 {
    const x: i32 = 1;
    const y: i32 = 2;
    inline var z: i32 = inline if (a) x else y;
    return z;
}

fn testInlineVarsAgain() {
    assert(gimme1or2(true) == 1);
    assert(gimme1or2(false) == 2);
}

fn first4KeysOfHomeRow() -> []const u8 {
    "aoeu"
}

fn testReturnStringFromFunction() {
    assert(memeql(first4KeysOfHomeRow(), "aoeu"));
}

pub fn memeql(a: []const u8, b: []const u8) -> bool {
    sliceEql(u8, a, b)
}

pub fn sliceEql(inline T: type, a: []const T, b: []const T) -> bool {
    if (a.len != b.len) return false;
    for (a) |item, index| {
        if (b[index] != item) return false;
    }
    return true;
}

error ItBroke;
fn gimmeItBroke() -> []const u8 {
    @errorName(error.ItBroke)
}

fn testErrorName() {
    assert(memeql(@errorName(error.ItBroke), "ItBroke"));
}

fn runAllTests() {
    testNamespaceFnCall();
    testStructStatic();
    testStaticFnEval();
    testCompileTimeFib();
    testCompileTimeGenericEval();
    testFnWithInlineArgs();
    testContinueInForLoop();
    shortCircuit();
    testStaticAddOne();
    testInlineVarsAgain();
    testMinValueAndMaxValue();
    testReturnStringFromFunction();
    testErrorName();
}

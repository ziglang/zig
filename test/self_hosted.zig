const std = @import("std");
const assert = std.debug.assert;
const str = std.str;
const cstr = std.cstr;
const test_return_type_type = @import("cases/return_type_type.zig");
const test_zeroes = @import("cases/zeroes.zig");
const test_sizeof_and_typeof = @import("cases/sizeof_and_typeof.zig");
const test_maybe_return = @import("cases/maybe_return.zig");
const test_max_value_type = @import("cases/max_value_type.zig");
const test_var_params = @import("cases/var_params.zig");
const test_const_slice_child = @import("cases/const_slice_child.zig");
const test_switch_prong_implicit_cast = @import("cases/switch_prong_implicit_cast.zig");
const test_switch_prong_err_enum = @import("cases/switch_prong_err_enum.zig");
const test_enum_with_members = @import("cases/enum_with_members.zig");
const test_struct_contains_slice_of_itself = @import("cases/struct_contains_slice_of_itself.zig");
const test_this = @import("cases/this.zig");



struct Node {
    val: Val,
    next: &Node,
}

struct Val {
    x: i32,
}

fn structPointToSelf() {
    @setFnTest(this, true);

    var root : Node = undefined;
    root.val.x = 1;

    var node : Node = undefined;
    node.next = &root;
    node.val.x = 2;

    root.next = &node;

    assert(node.next.next.next.val.x == 1);
}

fn structByvalAssign() {
    @setFnTest(this, true);

    var foo1 : StructFoo = undefined;
    var foo2 : StructFoo = undefined;

    foo1.a = 1234;
    foo2.a = 0;
    assert(foo2.a == 0);
    foo2 = foo1;
    assert(foo2.a == 1234);
}

fn structInitializer() {
    const val = Val { .x = 42 };
    assert(val.x == 42);
}


const g1 : i32 = 1233 + 1;
var g2 : i32 = 0;

fn globalVariables() {
    @setFnTest(this, true);

    assert(g2 == 0);
    g2 = g1;
    assert(g2 == 1234);
}


fn whileLoop() {
    @setFnTest(this, true);

    var i : i32 = 0;
    while (i < 4) {
        i += 1;
    }
    assert(i == 4);
    assert(whileLoop1() == 1);
}
fn whileLoop1() -> i32 {
    return whileLoop2();
}
fn whileLoop2() -> i32 {
    while (true) {
        return 1;
    }
}

fn voidArrays() {
    @setFnTest(this, true);

    var array: [4]void = undefined;
    array[0] = void{};
    array[1] = array[2];
    assert(@sizeOf(@typeOf(array)) == 0);
    assert(array.len == 4);
}


fn threeExprInARow() {
    @setFnTest(this, true);

    assertFalse(false || false || false);
    assertFalse(true && true && false);
    assertFalse(1 | 2 | 4 != 7);
    assertFalse(3 ^ 6 ^ 8 != 13);
    assertFalse(7 & 14 & 28 != 4);
    assertFalse(9  << 1 << 2 != 9  << 3);
    assertFalse(90 >> 1 >> 2 != 90 >> 3);
    assertFalse(100 - 1 + 1000 != 1099);
    assertFalse(5 * 4 / 2 % 3 != 1);
    assertFalse(i32(i32(5)) != 5);
    assertFalse(!!false);
    assertFalse(i32(7) != --(i32(7)));
}
fn assertFalse(b: bool) {
    assert(!b);
}


fn maybeType() {
    @setFnTest(this, true);

    const x : ?bool = true;

    if (const y ?= x) {
        if (y) {
            // OK
        } else {
            @unreachable();
        }
    } else {
        @unreachable();
    }

    const next_x : ?i32 = null;

    const z = next_x ?? 1234;

    assert(z == 1234);

    const final_x : ?i32 = 13;

    const num = final_x ?? @unreachable();

    assert(num == 13);
}


fn arrayLiteral() {
    @setFnTest(this, true);

    const hex_mult = []u16{4096, 256, 16, 1};

    assert(hex_mult.len == 4);
    assert(hex_mult[1] == 256);
}


fn constNumberLiteral() {
    @setFnTest(this, true);

    const one = 1;
    const eleven = ten + one;

    assert(eleven == 11);
}
const ten = 10;


fn errorValues() {
    @setFnTest(this, true);

    const a = i32(error.err1);
    const b = i32(error.err2);
    assert(a != b);
}
error err1;
error err2;



fn fnCallOfStructField() {
    @setFnTest(this, true);

    assert(callStructField(Foo {.ptr = aFunc,}) == 13);
}

struct Foo {
    ptr: fn() -> i32,
}

fn aFunc() -> i32 { 13 }

fn callStructField(foo: Foo) -> i32 {
    return foo.ptr();
}



fn redefinitionOfErrorValuesAllowed() {
    @setFnTest(this, true);

    shouldBeNotEqual(error.AnError, error.SecondError);
}
error AnError;
error AnError;
error SecondError;
fn shouldBeNotEqual(a: error, b: error) {
    if (a == b) @unreachable()
}




fn constantEnumWithPayload() {
    @setFnTest(this, true);

    var empty = AnEnumWithPayload.Empty;
    var full = AnEnumWithPayload.Full {13};
    shouldBeEmpty(empty);
    shouldBeNotEmpty(full);
}

fn shouldBeEmpty(x: AnEnumWithPayload) {
    switch (x) {
        Empty => {},
        else => @unreachable(),
    }
}

fn shouldBeNotEmpty(x: AnEnumWithPayload) {
    switch (x) {
        Empty => @unreachable(),
        else => {},
    }
}

enum AnEnumWithPayload {
    Empty,
    Full: i32,
}


fn castBoolToInt() {
    @setFnTest(this, true);

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


fn switchOnEnum() {
    @setFnTest(this, true);

    const fruit = Fruit.Orange;
    nonConstSwitchOnEnum(fruit);
}
enum Fruit {
    Apple,
    Orange,
    Banana,
}
fn nonConstSwitchOnEnum(fruit: Fruit) {
    @setFnStaticEval(this, false);

    switch (fruit) {
        Apple => @unreachable(),
        Orange => {},
        Banana => @unreachable(),
    }
}

fn switchStatement() {
    @setFnTest(this, true);

    nonConstSwitch(SwitchStatmentFoo.C);
}
fn nonConstSwitch(foo: SwitchStatmentFoo) {
    @setFnStaticEval(this, false);

    const val: i32 = switch (foo) {
        A => 1,
        B => 2,
        C => 3,
        D => 4,
    };
    if (val != 3) @unreachable();
}
enum SwitchStatmentFoo {
    A,
    B,
    C,
    D,
}


fn switchProngWithVar() {
    @setFnTest(this, true);

    switchProngWithVarFn(SwitchProngWithVarEnum.One {13});
    switchProngWithVarFn(SwitchProngWithVarEnum.Two {13.0});
    switchProngWithVarFn(SwitchProngWithVarEnum.Meh);
}
enum SwitchProngWithVarEnum {
    One: i32,
    Two: f32,
    Meh,
}
fn switchProngWithVarFn(a: SwitchProngWithVarEnum) {
    @setFnStaticEval(this, false);

    switch(a) {
        One => |x| {
            if (x != 13) @unreachable();
        },
        Two => |x| {
            if (x != 13.0) @unreachable();
        },
        Meh => |x| {
            const v: void = x;
        },
    }
}


fn errReturnInAssignment() {
    @setFnTest(this, true);

    %%doErrReturnInAssignment();
}

fn doErrReturnInAssignment() -> %void {
    @setFnStaticEval(this, false);

    var x : i32 = undefined;
    x = %return makeANonErr();
}

fn makeANonErr() -> %i32 {
    return 1;
}



fn rhsMaybeUnwrapReturn() {
    @setFnTest(this, true);

    const x = ?true;
    const y = x ?? return;
}


fn implicitCastFnUnreachableReturn() {
    @setFnTest(this, true);

    wantsFnWithVoid(fnWithUnreachable);
}

fn wantsFnWithVoid(f: fn()) { }

fn fnWithUnreachable() -> unreachable {
    @unreachable()
}


fn explicitCastMaybePointers() {
    @setFnTest(this, true);

    const a: ?&i32 = undefined;
    const b: ?&f32 = (?&f32)(a);
}


fn constExprEvalOnSingleExprBlocks() {
    @setFnTest(this, true);

    assert(constExprEvalOnSingleExprBlocksFn(1, true) == 3);
}

fn constExprEvalOnSingleExprBlocksFn(x: i32, b: bool) -> i32 {
    const literal = 3;

    const result = if (b) {
        literal
    } else {
        x
    };

    return result;
}


fn builtinConstEval() {
    @setFnTest(this, true);

    const x : i32 = @constEval(1 + 2 + 3);
    assert(x == @constEval(6));
}

fn slicing() {
    @setFnTest(this, true);

    var array : [20]i32 = undefined;

    array[5] = 1234;

    var slice = array[5...10];

    if (slice.len != 5) @unreachable();

    const ptr = &slice[0];
    if (ptr[0] != 1234) @unreachable();

    var slice_rest = array[10...];
    if (slice_rest.len != 10) @unreachable();
}


fn memcpyAndMemsetIntrinsics() {
    @setFnTest(this, true);

    var foo : [20]u8 = undefined;
    var bar : [20]u8 = undefined;

    @memset(&foo[0], 'A', foo.len);
    @memcpy(&bar[0], &foo[0], bar.len);

    if (bar[11] != 'A') @unreachable();
}


fn arrayDotLenConstExpr() {
    @setFnTest(this, true);
}

struct ArrayDotLenConstExpr {
    y: [@constEval(some_array.len)]u8,
}
const some_array = []u8 {0, 1, 2, 3};


fn multilineString() {
    @setFnTest(this, true);

    const s1 =
        \\one
        \\two)
        \\three
    ;
    const s2 = "one\ntwo)\nthree";
    assert(str.eql(s1, s2));
}

fn multilineCString() {
    @setFnTest(this, true);

    const s1 =
        c\\one
        c\\two)
        c\\three
    ;
    const s2 = c"one\ntwo)\nthree";
    assert(cstr.cmp(s1, s2) == 0);
}



fn constantEqualFunctionPointers() {
    @setFnTest(this, true);

    const alias = emptyFn;
    assert(@constEval(emptyFn == alias));
}

fn emptyFn() {}


fn genericMallocFree() {
    @setFnTest(this, true);

    const a = %%memAlloc(u8, 10);
    memFree(u8, a);
}
const some_mem : [100]u8 = undefined;
fn memAlloc(inline T: type, n: usize) -> %[]T {
    @setFnStaticEval(this, false);

    return (&T)(&some_mem[0])[0...n];
}
fn memFree(inline T: type, mem: []T) { }


fn callFnWithEmptyString() {
    @setFnTest(this, true);

    acceptsString("");
}

fn acceptsString(foo: []u8) { }


fn hexEscape() {
    @setFnTest(this, true);

    assert(str.eql("\x68\x65\x6c\x6c\x6f", "hello"));
}


error AnError;
error ALongerErrorName;
fn errorNameString() {
    @setFnTest(this, true);

    assert(str.eql(@errorName(error.AnError), "AnError"));
    assert(str.eql(@errorName(error.ALongerErrorName), "ALongerErrorName"));
}


fn castUndefined() {
    @setFnTest(this, true);

    const array: [100]u8 = undefined;
    const slice = ([]u8)(array);
    testCastUndefined(slice);
}
fn testCastUndefined(x: []u8) {}


fn castSmallUnsignedToLargerSigned() {
    @setFnTest(this, true);

    assert(castSmallUnsignedToLargerSigned1(200) == i16(200));
    assert(castSmallUnsignedToLargerSigned2(9999) == i64(9999));
}
fn castSmallUnsignedToLargerSigned1(x: u8) -> i16 { x }
fn castSmallUnsignedToLargerSigned2(x: u16) -> i64 { x }


fn implicitCastAfterUnreachable() {
    @setFnTest(this, true);

    assert(outer() == 1234);
}
fn inner() -> i32 { 1234 }
fn outer() -> i64 {
    return inner();
}


fn elseIfExpression() {
    @setFnTest(this, true);

    assert(elseIfExpressionF(1) == 1);
}
fn elseIfExpressionF(c: u8) -> u8 {
    if (c == 0) {
        0
    } else if (c == 1) {
        1
    } else {
        2
    }
}

fn errBinaryOperator() {
    @setFnTest(this, true);

    const a = errBinaryOperatorG(true) %% 3;
    const b = errBinaryOperatorG(false) %% 3;
    assert(a == 3);
    assert(b == 10);
}
error ItBroke;
fn errBinaryOperatorG(x: bool) -> %isize {
    if (x) {
        error.ItBroke
    } else {
        10
    }
}

fn unwrapSimpleValueFromError() {
    @setFnTest(this, true);

    const i = %%unwrapSimpleValueFromErrorDo();
    assert(i == 13);
}
fn unwrapSimpleValueFromErrorDo() -> %isize { 13 }


fn storeMemberFunctionInVariable() {
    @setFnTest(this, true);

    const instance = MemberFnTestFoo { .x = 1234, };
    const memberFn = MemberFnTestFoo.member;
    const result = memberFn(instance);
    assert(result == 1234);
}
struct MemberFnTestFoo {
    x: i32,
    fn member(foo: MemberFnTestFoo) -> i32 { foo.x }
}

fn callMemberFunctionDirectly() {
    @setFnTest(this, true);

    const instance = MemberFnTestFoo { .x = 1234, };
    const result = MemberFnTestFoo.member(instance);
    assert(result == 1234);
}

fn memberFunctions() {
    @setFnTest(this, true);

    const r = MemberFnRand {.seed = 1234};
    assert(r.getSeed() == 1234);
}
struct MemberFnRand {
    seed: u32,
    pub fn getSeed(r: MemberFnRand) -> u32 {
        r.seed
    }
}

fn staticFunctionEvaluation() {
    @setFnTest(this, true);

    assert(statically_added_number == 3);
}
const statically_added_number = staticAdd(1, 2);
fn staticAdd(a: i32, b: i32) -> i32 { a + b }


fn staticallyInitalizedList() {
    @setFnTest(this, true);

    assert(static_point_list[0].x == 1);
    assert(static_point_list[0].y == 2);
    assert(static_point_list[1].x == 3);
    assert(static_point_list[1].y == 4);
}
struct Point {
    x: i32,
    y: i32,
}
const static_point_list = []Point { makePoint(1, 2), makePoint(3, 4) };
fn makePoint(x: i32, y: i32) -> Point {
    return Point {
        .x = x,
        .y = y,
    };
}


fn staticEvalRecursive() {
    @setFnTest(this, true);

    assert(some_data.len == 21);
}
var some_data: [usize(fibbonaci(7))]u8 = undefined;
fn fibbonaci(x: i32) -> i32 {
    if (x <= 1) return 1;
    return fibbonaci(x - 1) + fibbonaci(x - 2);
}

fn staticEvalWhile() {
    @setFnTest(this, true);

    assert(static_eval_while_number == 1);
}
const static_eval_while_number = staticWhileLoop1();
fn staticWhileLoop1() -> i32 {
    return whileLoop2();
}
fn staticWhileLoop2() -> i32 {
    while (true) {
        return 1;
    }
}

fn staticEvalListInit() {
    @setFnTest(this, true);

    assert(static_vec3.data[2] == 1.0);
}
const static_vec3 = vec3(0.0, 0.0, 1.0);
pub struct Vec3 {
    data: [3]f32,
}
pub fn vec3(x: f32, y: f32, z: f32) -> Vec3 {
    Vec3 {
        .data = []f32 { x, y, z, },
    }
}


fn genericFnWithImplicitCast() {
    @setFnTest(this, true);

    assert(getFirstByte(u8, []u8 {13}) == 13);
    assert(getFirstByte(u16, []u16 {0, 13}) == 0);
}
fn getByte(ptr: ?&u8) -> u8 {*??ptr}
fn getFirstByte(inline T: type, mem: []T) -> u8 {
    getByte((&u8)(&mem[0]))
}

fn continueAndBreak() {
    @setFnTest(this, true);

    runContinueAndBreakTest();
    assert(continue_and_break_counter == 8);
}
var continue_and_break_counter: i32 = 0;
fn runContinueAndBreakTest() {
    var i : i32 = 0;
    while (true) {
        continue_and_break_counter += 2;
        i += 1;
        if (i < 4) {
            continue;
        }
        break;
    }
    assert(i == 4);
}


fn pointerDereferencing() {
    @setFnTest(this, true);

    var x = i32(3);
    const y = &x;

    *y += 1;

    assert(x == 4);
    assert(*y == 4);
}

fn constantExpressions() {
    @setFnTest(this, true);

    var array : [array_size]u8 = undefined;
    assert(@sizeOf(@typeOf(array)) == 20);
}
const array_size : u8 = 20;


fn nestedArrays() {
    @setFnTest(this, true);

    const array_of_strings = [][]u8 {"hello", "this", "is", "my", "thing"};
    for (array_of_strings) |s, i| {
        if (i == 0) assert(str.eql(s, "hello"));
        if (i == 1) assert(str.eql(s, "this"));
        if (i == 2) assert(str.eql(s, "is"));
        if (i == 3) assert(str.eql(s, "my"));
        if (i == 4) assert(str.eql(s, "thing"));
    }
}

fn intToPtrCast() {
    @setFnTest(this, true);

    const x = isize(13);
    const y = (&u8)(x);
    const z = usize(y);
    assert(z == 13);
}

fn stringConcatenation() {
    @setFnTest(this, true);

    assert(str.eql("OK" ++ " IT " ++ "WORKED", "OK IT WORKED"));
}

fn constantStructWithNegation() {
    @setFnTest(this, true);

    assert(vertices[0].x == -0.6);
}
struct Vertex {
    x: f32,
    y: f32,
    r: f32,
    g: f32,
    b: f32,
}
const vertices = []Vertex {
    Vertex { .x = -0.6, .y = -0.4, .r = 1.0, .g = 0.0, .b = 0.0 },
    Vertex { .x =  0.6, .y = -0.4, .r = 0.0, .g = 1.0, .b = 0.0 },
    Vertex { .x =  0.0, .y =  0.6, .r = 0.0, .g = 0.0, .b = 1.0 },
};


fn returnWithImplicitCastFromWhileLoop() {
    @setFnTest(this, true);

    %%returnWithImplicitCastFromWhileLoopTest();
}
fn returnWithImplicitCastFromWhileLoopTest() -> %void {
    while (true) {
        return;
    }
}

fn returnStructByvalFromFunction() {
    @setFnTest(this, true);

    const bar = makeBar(1234, 5678);
    assert(bar.y == 5678);
}
struct Bar {
    x: i32,
    y: i32,
}
fn makeBar(x: i32, y: i32) -> Bar {
    Bar {
        .x = x,
        .y = y,
    }
}

fn functionPointers() {
    @setFnTest(this, true);

    const fns = []@typeOf(fn1) { fn1, fn2, fn3, fn4, };
    for (fns) |f, i| {
        assert(f() == u32(i) + 5);
    }
}
fn fn1() -> u32 {5}
fn fn2() -> u32 {6}
fn fn3() -> u32 {7}
fn fn4() -> u32 {8}



fn staticallyInitalizedStruct() {
    @setFnTest(this, true);

    st_init_str_foo.x += 1;
    assert(st_init_str_foo.x == 14);
}
struct StInitStrFoo {
    x: i32,
    y: bool,
}
var st_init_str_foo = StInitStrFoo { .x = 13, .y = true, };

fn staticallyInitializedArrayLiteral() {
    @setFnTest(this, true);

    const y : [4]u8 = st_init_arr_lit_x;
    assert(y[3] == 4);
}
const st_init_arr_lit_x = []u8{1,2,3,4};



fn pointerToVoidReturnType() {
    @setFnTest(this, true);

    %%testPointerToVoidReturnType();
}
fn testPointerToVoidReturnType() -> %void {
    const a = testPointerToVoidReturnType2();
    return *a;
}
const test_pointer_to_void_return_type_x = void{};
fn testPointerToVoidReturnType2() -> &void {
    return &test_pointer_to_void_return_type_x;
}


fn callResultOfIfElseExpression() {
    @setFnTest(this, true);

    assert(str.eql(f2(true), "a"));
    assert(str.eql(f2(false), "b"));
}
fn f2(x: bool) -> []u8 {
    return (if (x) fA else fB)();
}
fn fA() -> []u8 { "a" }
fn fB() -> []u8 { "b" }


fn constExpressionEvalHandlingOfVariables() {
    @setFnTest(this, true);

    var x = true;
    while (x) {
        x = false;
    }
}



fn constantEnumInitializationWithDifferingSizes() {
    @setFnTest(this, true);

    test3_1(test3_foo);
    test3_2(test3_bar);
}
enum Test3Foo {
    One,
    Two: f32,
    Three: Test3Point,
}
struct Test3Point {
    x: i32,
    y: i32,
}
const test3_foo = Test3Foo.Three{Test3Point {.x = 3, .y = 4}};
const test3_bar = Test3Foo.Two{13};
fn test3_1(f: Test3Foo) {
    @setFnStaticEval(this, false);

    switch (f) {
        Three => |pt| {
            assert(pt.x == 3);
            assert(pt.y == 4);
        },
        else => @unreachable(),
    }
}
fn test3_2(f: Test3Foo) {
    @setFnStaticEval(this, false);

    switch (f) {
        Two => |x| {
            assert(x == 13);
        },
        else => @unreachable(),
    }
}



fn whileWithContinueExpr() {
    @setFnTest(this, true);

    var sum: i32 = 0;
    {var i: i32 = 0; while (i < 10; i += 1) {
        if (i == 5) continue;
        sum += i;
    }}
    assert(sum == 40);
}


fn forLoopWithPointerElemVar() {
    @setFnTest(this, true);

    const source = "abcdefg";
    var target: [source.len]u8 = undefined;
    @memcpy(&target[0], &source[0], source.len);
    mangleString(target);
    assert(str.eql(target, "bcdefgh"));
}
fn mangleString(s: []u8) {
    @setFnStaticEval(this, false);

    for (s) |*c| {
        *c += 1;
    }
}

fn emptyStructMethodCall() {
    @setFnTest(this, true);

    const es = EmptyStruct{};
    assert(es.method() == 1234);
}
struct EmptyStruct {
    fn method(es: EmptyStruct) -> i32 {
        @setFnStaticEval(this, false);
        1234
    }

}


fn @"weird function name"() {
    @setFnTest(this, true);
}



fn returnEmptyStructFromFn() {
    @setFnTest(this, true);

    testReturnEmptyStructFromFn();
    testReturnEmptyStructFromFnNoeval();
}
struct EmptyStruct2 {}
fn testReturnEmptyStructFromFn() -> EmptyStruct2 {
    EmptyStruct2 {}
}
fn testReturnEmptyStructFromFnNoeval() -> EmptyStruct2 {
    @setFnStaticEval(this, false);

    EmptyStruct2 {}
}

fn passSliceOfEmptyStructToFn() {
    @setFnTest(this, true);

    assert(testPassSliceOfEmptyStructToFn([]EmptyStruct2{ EmptyStruct2{} }) == 1);
}
fn testPassSliceOfEmptyStructToFn(slice: []EmptyStruct2) -> usize {
    slice.len
}


fn pointerComparison() {
    @setFnTest(this, true);

    const a = ([]u8)("a");
    const b = &a;
    assert(ptrEql(b, b));
}
fn ptrEql(a: &[]u8, b: &[]u8) -> bool {
    a == b
}

fn characterLiterals() {
    @setFnTest(this, true);

    assert('\'' == single_quote);
}
const single_quote = '\'';


fn switchWithMultipleExpressions() {
    @setFnTest(this, true);

    const x: i32 = switch (returnsFive()) {
        1, 2, 3 => 1,
        4, 5, 6 => 2,
        else => 3,
    };
    assert(x == 2);
}
fn returnsFive() -> i32 {
    @setFnStaticEval(this, false);
    5
}



fn switchOnErrorUnion() {
    @setFnTest(this, true);

    const x = switch (returnsTen()) {
        Ok => |val| val + 1,
        ItBroke, NoMem => 1,
        CrappedOut => 2,
    };
    assert(x == 11);
}
error ItBroke;
error NoMem;
error CrappedOut;
fn returnsTen() -> %i32 {
    @setFnStaticEval(this, false);
    10
}



fn boolCmp() {
    @setFnTest(this, true);

    assert(testBoolCmp(true, false) == false);
}
fn testBoolCmp(a: bool, b: bool) -> bool {
    @setFnStaticEval(this, false);
    a == b
}



fn takeAddressOfParameter() {
    @setFnTest(this, true);

    testTakeAddressOfParameter(12.34);
    testTakeAddressOfParameterNoeval(12.34);
}
fn testTakeAddressOfParameter(f: f32) {
    const f_ptr = &f;
    assert(*f_ptr == 12.34);
}
fn testTakeAddressOfParameterNoeval(f: f32) {
    @setFnStaticEval(this, false);

    const f_ptr = &f;
    assert(*f_ptr == 12.34);
}


fn arrayMultOperator() {
    @setFnTest(this, true);

    assert(str.eql("ab" ** 5, "ababababab"));
}

fn stringEscapes() {
    @setFnTest(this, true);

    assert(str.eql("\"", "\x22"));
    assert(str.eql("\'", "\x27"));
    assert(str.eql("\n", "\x0a"));
    assert(str.eql("\r", "\x0d"));
    assert(str.eql("\t", "\x09"));
    assert(str.eql("\\", "\x5c"));
    assert(str.eql("\u1234\u0069", "\xe1\x88\xb4\x69"));
}

fn ifVarMaybePointer() {
    @setFnTest(this, true);

    assert(shouldBeAPlus1(Particle {.a = 14, .b = 1, .c = 1, .d = 1}) == 15);
}
fn shouldBeAPlus1(p: Particle) -> u64 {
    @setFnStaticEval(this, false);

    var maybe_particle: ?Particle = p;
    if (const *particle ?= maybe_particle) {
        particle.a += 1;
    }
    if (const particle ?= maybe_particle) {
        return particle.a;
    }
    return 0;
}
struct Particle {
    a: u64,
    b: u64,
    c: u64,
    d: u64,
}

fn assignToIfVarPtr() {
    @setFnTest(this, true);

    var maybe_bool: ?bool = true;

    if (const *b ?= maybe_bool) {
        *b = false;
    }

    assert(??maybe_bool == false);
}

fn unsignedWrapping() {
    @setFnTest(this, true);

    testUnsignedWrappingEval(@maxValue(u32));
    testUnsignedWrappingNoeval(@maxValue(u32));
}
fn testUnsignedWrappingEval(x: u32) {
    const zero = x +% 1;
    assert(zero == 0);
    const orig = zero -% 1;
    assert(orig == @maxValue(u32));
}
fn testUnsignedWrappingNoeval(x: u32) {
    @setFnStaticEval(this, false);

    const zero = x +% 1;
    assert(zero == 0);
    const orig = zero -% 1;
    assert(orig == @maxValue(u32));
}

fn signedWrapping() {
    @setFnTest(this, true);

    testSignedWrappingEval(@maxValue(i32));
    testSignedWrappingNoeval(@maxValue(i32));
}
fn testSignedWrappingEval(x: i32) {
    const min_val = x +% 1;
    assert(min_val == @minValue(i32));
    const max_val = min_val -% 1;
    assert(max_val == @maxValue(i32));
}
fn testSignedWrappingNoeval(x: i32) {
    @setFnStaticEval(this, false);

    const min_val = x +% 1;
    assert(min_val == @minValue(i32));
    const max_val = min_val -% 1;
    assert(max_val == @maxValue(i32));
}

fn negationWrapping() {
    @setFnTest(this, true);

    testNegationWrappingEval(@minValue(i16));
    testNegationWrappingNoeval(@minValue(i16));
}
fn testNegationWrappingEval(x: i16) {
    assert(x == -32768);
    const neg = -%x;
    assert(neg == -32768);
}
fn testNegationWrappingNoeval(x: i16) {
    @setFnStaticEval(this, false);

    assert(x == -32768);
    const neg = -%x;
    assert(neg == -32768);
}

fn shlWrapping() {
    @setFnTest(this, true);

    testShlWrappingEval(@maxValue(u16));
    testShlWrappingNoeval(@maxValue(u16));
}
fn testShlWrappingEval(x: u16) {
    const shifted = x <<% 1;
    assert(shifted == 65534);
}
fn testShlWrappingNoeval(x: u16) {
    @setFnStaticEval(this, false);

    const shifted = x <<% 1;
    assert(shifted == 65534);
}

fn cStringConcatenation() {
    @setFnTest(this, true);

    const a = c"OK" ++ c" IT " ++ c"WORKED";
    const b = c"OK IT WORKED";

    const len = cstr.len(b);
    const len_with_null = len + 1;
    {var i: u32 = 0; while (i < len_with_null; i += 1) {
        assert(a[i] == b[i]);
    }}
    assert(a[len] == 0);
    assert(b[len] == 0);
}

fn genericStruct() {
    @setFnTest(this, true);

    var a1 = GenNode(i32) {.value = 13, .next = null,};
    var b1 = GenNode(bool) {.value = true, .next = null,};
    assert(a1.value == 13);
    assert(a1.value == a1.getVal());
    assert(b1.getVal());
}
struct GenNode(T: type) {
    value: T,
    next: ?&GenNode(T),
    fn getVal(n: &const GenNode(T)) -> T { n.value }
}

fn castSliceToU8Slice() {
    @setFnTest(this, true);

    assert(@sizeOf(i32) == 4);
    var big_thing_array = []i32{1, 2, 3, 4};
    const big_thing_slice: []i32 = big_thing_array;
    const bytes = ([]u8)(big_thing_slice);
    assert(bytes.len == 4 * 4);
    bytes[4] = 0;
    bytes[5] = 0;
    bytes[6] = 0;
    bytes[7] = 0;
    assert(big_thing_slice[1] == 0);
    const big_thing_again = ([]i32)(bytes);
    assert(big_thing_again[2] == 3);
    big_thing_again[2] = -1;
    assert(bytes[8] == @maxValue(u8));
    assert(bytes[9] == @maxValue(u8));
    assert(bytes[10] == @maxValue(u8));
    assert(bytes[11] == @maxValue(u8));
}

fn nullLiteralOutsideFunction() {
    @setFnTest(this, true);

    const is_null = if (const _ ?= here_is_a_null_literal.context) false else true;
    assert(is_null);
}
struct SillyStruct {
    context: ?i32,
}
const here_is_a_null_literal = SillyStruct {
    .context = null,
};

fn constDeclsInStruct() {
    @setFnTest(this, true);

    assert(GenericDataThing(3).count_plus_one == 4);
}
struct GenericDataThing(count: isize) {
    const count_plus_one = count + 1;
}

fn useGenericParamInGenericParam() {
    @setFnTest(this, true);

    assert(aGenericFn(i32, 3, 4) == 7);
}
fn aGenericFn(inline T: type, inline a: T, b: T) -> T {
    return a + b;
}


fn unsigned64BitDivision() {
    @setFnTest(this, true);

    const result = div(1152921504606846976, 34359738365);
    assert(result.quotient == 33554432);
    assert(result.remainder == 100663296);
}
fn div(a: u64, b: u64) -> DivResult {
    @setFnStaticEval(this, false);

    DivResult {
        .quotient = a / b,
        .remainder = a % b,
    }
}
struct DivResult {
    quotient: u64,
    remainder: u64,
}

fn intToEnum() {
    @setFnTest(this, true);

    testIntToEnumEval(3);
    testIntToEnumNoeval(3);
}
fn testIntToEnumEval(x: i32) {
    assert(IntToEnumNumber(x) == IntToEnumNumber.Three);
}
fn testIntToEnumNoeval(x: i32) {
    @setFnStaticEval(this, false);

    assert(IntToEnumNumber(x) == IntToEnumNumber.Three);
}
enum IntToEnumNumber {
    Zero,
    One,
    Two,
    Three,
    Four,
}

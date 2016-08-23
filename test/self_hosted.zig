const std = @import("std");
const assert = std.debug.assert;
const str = std.str;
const cstr = std.cstr;
const other = @import("other.zig");
const test_return_type_type = @import("cases/return_type_type.zig");
const test_zeroes = @import("cases/zeroes.zig");
const test_sizeof_and_typeof = @import("cases/sizeof_and_typeof.zig");
const test_maybe_return = @import("cases/maybe_return.zig");

// normal comment
/// this is a documentation comment
/// doc comment line 2
#attribute("test")
fn emptyFunctionWithComments() {}


#attribute("test")
fn ifStatements() {
    shouldBeEqual(1, 1);
    firstEqlThird(2, 1, 2);
}
fn shouldBeEqual(a: i32, b: i32) {
    if (a != b) {
        unreachable{};
    } else {
        return;
    }
}
fn firstEqlThird(a: i32, b: i32, c: i32) {
    if (a == b) {
        unreachable{};
    } else if (b == c) {
        unreachable{};
    } else if (a == c) {
        return;
    } else {
        unreachable{};
    }
}


#attribute("test")
fn params() {
    assert(testParamsAdd(22, 11) == 33);
}
fn testParamsAdd(a: i32, b: i32) -> i32 {
    a + b
}


#attribute("test")
fn localVariables() {
    testLocVars(2);
}
fn testLocVars(b: i32) {
    const a: i32 = 1;
    if (a + b != 3) unreachable{};
}

#attribute("test")
fn boolLiterals() {
    assert(true);
    assert(!false);
}

#attribute("test")
fn voidParameters() {
    voidFun(1, void{}, 2, {});
}
fn voidFun(a : i32, b : void, c : i32, d : void) {
    const v = b;
    const vv : void = if (a == 1) {v} else {};
    assert(a + c == 3);
    return vv;
}

#attribute("test")
fn mutableLocalVariables() {
    var zero : i32 = 0;
    assert(zero == 0);

    var i = i32(0);
    while (i != 3) {
        i += 1;
    }
    assert(i == 3);
}

#attribute("test")
fn arrays() {
    var array : [5]u32 = undefined;

    var i : u32 = 0;
    while (i < 5) {
        array[i] = i + 1;
        i = array[i];
    }

    i = 0;
    var accumulator = u32(0);
    while (i < 5) {
        accumulator += array[i];

        i += 1;
    }

    assert(accumulator == 15);
    assert(getArrayLen(array) == 5);
}
fn getArrayLen(a: []u32) -> usize {
    a.len
}

#attribute("test")
fn shortCircuit() {
    var hit_1 = false;
    var hit_2 = false;
    var hit_3 = false;
    var hit_4 = false;

    if (true || {assertRuntime(false); false}) {
        hit_1 = true;
    }
    if (false || { hit_2 = true; false }) {
        assertRuntime(false);
    }

    if (true && { hit_3 = true; false }) {
        assertRuntime(false);
    }
    if (false && {assertRuntime(false); false}) {
        assertRuntime(false);
    } else {
        hit_4 = true;
    }
    assert(hit_1);
    assert(hit_2);
    assert(hit_3);
    assert(hit_4);
}

#static_eval_enable(false)
fn assertRuntime(b: bool) {
    if (!b) unreachable{}
}

#attribute("test")
fn modifyOperators() {
    var i : i32 = 0;
    i += 5;  assert(i == 5);
    i -= 2;  assert(i == 3);
    i *= 20; assert(i == 60);
    i /= 3;  assert(i == 20);
    i %= 11; assert(i == 9);
    i <<= 1; assert(i == 18);
    i >>= 2; assert(i == 4);
    i = 6;
    i &= 5;  assert(i == 4);
    i ^= 6;  assert(i == 2);
    i = 6;
    i |= 3;  assert(i == 7);
}


#attribute("test")
fn separateBlockScopes() {
    {
        const no_conflict : i32 = 5;
        assert(no_conflict == 5);
    }

    const c = {
        const no_conflict = i32(10);
        no_conflict
    };
    assert(c == 10);
}


#attribute("test")
fn voidStructFields() {
    const foo = VoidStructFieldsFoo {
        .a = void{},
        .b = 1,
        .c = void{},
    };
    assert(foo.b == 1);
    assert(@sizeOf(VoidStructFieldsFoo) == 4);
}
struct VoidStructFieldsFoo {
    a : void,
    b : i32,
    c : void,
}



#attribute("test")
pub fn structs() {
    var foo : StructFoo = undefined;
    @memset(&foo, 0, @sizeOf(StructFoo));
    foo.a += 1;
    foo.b = foo.a == 1;
    testFoo(foo);
    testMutation(&foo);
    assert(foo.c == 100);
}
struct StructFoo {
    a : i32,
    b : bool,
    c : f32,
}
fn testFoo(foo : StructFoo) {
    assert(foo.b);
}
fn testMutation(foo : &StructFoo) {
    foo.c = 100;
}
struct Node {
    val: Val,
    next: &Node,
}

struct Val {
    x: i32,
}

#attribute("test")
fn structPointToSelf() {
    var root : Node = undefined;
    root.val.x = 1;

    var node : Node = undefined;
    node.next = &root;
    node.val.x = 2;

    root.next = &node;

    assert(node.next.next.next.val.x == 1);
}

#attribute("test")
fn structByvalAssign() {
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

#attribute("test")
fn globalVariables() {
    assert(g2 == 0);
    g2 = g1;
    assert(g2 == 1234);
}


#attribute("test")
fn whileLoop() {
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

#attribute("test")
fn voidArrays() {
    var array: [4]void = undefined;
    array[0] = void{};
    array[1] = array[2];
    assert(@sizeOf(@typeOf(array)) == 0);
    assert(array.len == 4);
}


#attribute("test")
fn threeExprInARow() {
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


#attribute("test")
fn maybeType() {
    const x : ?bool = true;

    if (const y ?= x) {
        if (y) {
            // OK
        } else {
            unreachable{};
        }
    } else {
        unreachable{};
    }

    const next_x : ?i32 = null;

    const z = next_x ?? 1234;

    assert(z == 1234);

    const final_x : ?i32 = 13;

    const num = final_x ?? unreachable{};

    assert(num == 13);
}


#attribute("test")
fn enumType() {
    const foo1 = EnumTypeFoo.One {13};
    const foo2 = EnumTypeFoo.Two {EnumType { .x = 1234, .y = 5678, }};
    const bar = EnumTypeBar.B;

    assert(bar == EnumTypeBar.B);
    assert(@memberCount(EnumTypeFoo) == 3);
    assert(@memberCount(EnumTypeBar) == 4);
    const expected_foo_size = switch (@compileVar("arch")) {
        i386 => 20,
        x86_64 => 24,
        else => unreachable{},
    };
    assert(@sizeOf(EnumTypeFoo) == expected_foo_size);
    assert(@sizeOf(EnumTypeBar) == 1);
}
struct EnumType {
    x: u64,
    y: u64,
}
enum EnumTypeFoo {
    One: i32,
    Two: EnumType,
    Three: void,
}
enum EnumTypeBar {
    A,
    B,
    C,
    D,
}


#attribute("test")
fn arrayLiteral() {
    const hex_mult = []u16{4096, 256, 16, 1};

    assert(hex_mult.len == 4);
    assert(hex_mult[1] == 256);
}


#attribute("test")
fn constNumberLiteral() {
    const one = 1;
    const eleven = ten + one;

    assert(eleven == 11);
}
const ten = 10;


#attribute("test")
fn errorValues() {
    const a = i32(error.err1);
    const b = i32(error.err2);
    assert(a != b);
}
error err1;
error err2;



#attribute("test")
fn fnCallOfStructField() {
    assert(callStructField(Foo {.ptr = aFunc,}) == 13);
}

struct Foo {
    ptr: fn() -> i32,
}

fn aFunc() -> i32 { 13 }

fn callStructField(foo: Foo) -> i32 {
    return foo.ptr();
}



#attribute("test")
fn redefinitionOfErrorValuesAllowed() {
    shouldBeNotEqual(error.AnError, error.SecondError);
}
error AnError;
error AnError;
error SecondError;
fn shouldBeNotEqual(a: error, b: error) {
    if (a == b) unreachable{}
}




#attribute("test")
fn constantEnumWithPayload() {
    var empty = AnEnumWithPayload.Empty;
    var full = AnEnumWithPayload.Full {13};
    shouldBeEmpty(empty);
    shouldBeNotEmpty(full);
}

fn shouldBeEmpty(x: AnEnumWithPayload) {
    switch (x) {
        Empty => {},
        else => unreachable{},
    }
}

fn shouldBeNotEmpty(x: AnEnumWithPayload) {
    switch (x) {
        Empty => unreachable{},
        else => {},
    }
}

enum AnEnumWithPayload {
    Empty,
    Full: i32,
}


#attribute("test")
fn continueInForLoop() {
    const array = []i32 {1, 2, 3, 4, 5};
    var sum : i32 = 0;
    for (array) |x| {
        sum += x;
        if (x < 3) {
            continue;
        }
        break;
    }
    if (sum != 6) unreachable{}
}


#attribute("test")
fn castBoolToInt() {
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


#attribute("test")
fn switchOnEnum() {
    const fruit = Fruit.Orange;
    nonConstSwitchOnEnum(fruit);
}
enum Fruit {
    Apple,
    Orange,
    Banana,
}
#static_eval_enable(false)
fn nonConstSwitchOnEnum(fruit: Fruit) {
    switch (fruit) {
        Apple => unreachable{},
        Orange => {},
        Banana => unreachable{},
    }
}

#attribute("test")
fn switchStatement() {
    nonConstSwitch(SwitchStatmentFoo.C);
}
#static_eval_enable(false)
fn nonConstSwitch(foo: SwitchStatmentFoo) {
    const val: i32 = switch (foo) {
        A => 1,
        B => 2,
        C => 3,
        D => 4,
    };
    if (val != 3) unreachable{};
}
enum SwitchStatmentFoo {
    A,
    B,
    C,
    D,
}


#attribute("test")
fn switchProngWithVar() {
    switchProngWithVarFn(SwitchProngWithVarEnum.One {13});
    switchProngWithVarFn(SwitchProngWithVarEnum.Two {13.0});
    switchProngWithVarFn(SwitchProngWithVarEnum.Meh);
}
enum SwitchProngWithVarEnum {
    One: i32,
    Two: f32,
    Meh,
}
#static_eval_enable(false)
fn switchProngWithVarFn(a: SwitchProngWithVarEnum) {
    switch(a) {
        One => |x| {
            if (x != 13) unreachable{};
        },
        Two => |x| {
            if (x != 13.0) unreachable{};
        },
        Meh => |x| {
            const v: void = x;
        },
    }
}


#attribute("test")
fn errReturnInAssignment() {
    %%doErrReturnInAssignment();
}

#static_eval_enable(false)
fn doErrReturnInAssignment() -> %void {
    var x : i32 = undefined;
    x = %return makeANonErr();
}

fn makeANonErr() -> %i32 {
    return 1;
}



#attribute("test")
fn rhsMaybeUnwrapReturn() {
    const x = ?true;
    const y = x ?? return;
}


#attribute("test")
fn implicitCastFnUnreachableReturn() {
    wantsFnWithVoid(fnWithUnreachable);
}

fn wantsFnWithVoid(f: fn()) { }

fn fnWithUnreachable() -> unreachable {
    unreachable {}
}


#attribute("test")
fn explicitCastMaybePointers() {
    const a: ?&i32 = undefined;
    const b: ?&f32 = (?&f32)(a);
}


#attribute("test")
fn constExprEvalOnSingleExprBlocks() {
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


#attribute("test")
fn builtinConstEval() {
    const x : i32 = @constEval(1 + 2 + 3);
    assert(x == @constEval(6));
}

#attribute("test")
fn slicing() {
    var array : [20]i32 = undefined;

    array[5] = 1234;

    var slice = array[5...10];

    if (slice.len != 5) unreachable{};

    const ptr = &slice[0];
    if (ptr[0] != 1234) unreachable{};

    var slice_rest = array[10...];
    if (slice_rest.len != 10) unreachable{};
}


#attribute("test")
fn memcpyAndMemsetIntrinsics() {
    var foo : [20]u8 = undefined;
    var bar : [20]u8 = undefined;

    @memset(&foo[0], 'A', foo.len);
    @memcpy(&bar[0], &foo[0], bar.len);

    if (bar[11] != 'A') unreachable{};
}


#attribute("test")
fn arrayDotLenConstExpr() { }
struct ArrayDotLenConstExpr {
    y: [@constEval(some_array.len)]u8,
}
const some_array = []u8 {0, 1, 2, 3};


#attribute("test")
fn countLeadingZeroes() {
    assert(@clz(u8, 0b00001010) == 4);
    assert(@clz(u8, 0b10001010) == 0);
    assert(@clz(u8, 0b00000000) == 8);
}

#attribute("test")
fn countTrailingZeroes() {
    assert(@ctz(u8, 0b10100000) == 5);
    assert(@ctz(u8, 0b10001010) == 1);
    assert(@ctz(u8, 0b00000000) == 8);
}


#attribute("test")
fn multilineString() {
    const s1 =
        \\one
        \\two)
        \\three
    ;
    const s2 = "one\ntwo)\nthree";
    assert(str.eql(s1, s2));
}

#attribute("test")
fn multilineCString() {
    const s1 =
        c\\one
        c\\two)
        c\\three
    ;
    const s2 = c"one\ntwo)\nthree";
    assert(cstr.cmp(s1, s2) == 0);
}



#attribute("test")
fn simpleGenericFn() {
    assert(max(i32, 3, -1) == 3);
    assert(max(f32, 0.123, 0.456) == 0.456);
    assert(add(2, 3) == 5);
}

fn max(inline T: type, a: T, b: T) -> T {
    return if (a > b) a else b;
}

fn add(inline a: i32, b: i32) -> i32 {
    return @constEval(a) + b;
}


#attribute("test")
fn constantEqualFunctionPointers() {
    const alias = emptyFn;
    assert(@constEval(emptyFn == alias));
}

fn emptyFn() {}


#attribute("test")
fn genericMallocFree() {
    const a = %%memAlloc(u8, 10);
    memFree(u8, a);
}
const some_mem : [100]u8 = undefined;
#static_eval_enable(false)
fn memAlloc(inline T: type, n: usize) -> %[]T {
    return (&T)(&some_mem[0])[0...n];
}
fn memFree(inline T: type, mem: []T) { }


#attribute("test")
fn callFnWithEmptyString() {
    acceptsString("");
}

fn acceptsString(foo: []u8) { }


#attribute("test")
fn hexEscape() {
    assert(str.eql("\x68\x65\x6c\x6c\x6f", "hello"));
}


error AnError;
error ALongerErrorName;
#attribute("test")
fn errorNameString() {
    assert(str.eql(@errName(error.AnError), "AnError"));
    assert(str.eql(@errName(error.ALongerErrorName), "ALongerErrorName"));
}


#attribute("test")
fn gotoAndLabels() {
    gotoLoop();
    assert(goto_counter == 10);
}
fn gotoLoop() {
    var i: i32 = 0;
    goto cond;
loop:
    i += 1;
cond:
    if (!(i < 10)) goto end;
    goto_counter += 1;
    goto loop;
end:
}
var goto_counter: i32 = 0;



#attribute("test")
fn gotoLeaveDeferScope() {
    testGotoLeaveDeferScope(true);
}
#static_eval_enable(false)
fn testGotoLeaveDeferScope(b: bool) {
    var it_worked = false;

    goto entry;
exit:
    if (it_worked) {
        return;
    }
    unreachable{};
entry:
    defer it_worked = true;
    if (b) goto exit;
}


#attribute("test")
fn castUndefined() {
    const array: [100]u8 = undefined;
    const slice = ([]u8)(array);
    testCastUndefined(slice);
}
fn testCastUndefined(x: []u8) {}


#attribute("test")
fn castSmallUnsignedToLargerSigned() {
    assert(castSmallUnsignedToLargerSigned1(200) == i16(200));
    assert(castSmallUnsignedToLargerSigned2(9999) == i64(9999));
}
fn castSmallUnsignedToLargerSigned1(x: u8) -> i16 { x }
fn castSmallUnsignedToLargerSigned2(x: u16) -> i64 { x }


#attribute("test")
fn implicitCastAfterUnreachable() {
    assert(outer() == 1234);
}
fn inner() -> i32 { 1234 }
fn outer() -> i64 {
    return inner();
}


#attribute("test")
fn elseIfExpression() {
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

#attribute("test")
fn errBinaryOperator() {
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

#attribute("test")
fn unwrapSimpleValueFromError() {
    const i = %%unwrapSimpleValueFromErrorDo();
    assert(i == 13);
}
fn unwrapSimpleValueFromErrorDo() -> %isize { 13 }


#attribute("test")
fn storeMemberFunctionInVariable() {
    const instance = MemberFnTestFoo { .x = 1234, };
    const memberFn = MemberFnTestFoo.member;
    const result = memberFn(instance);
    assert(result == 1234);
}
struct MemberFnTestFoo {
    x: i32,
    fn member(foo: MemberFnTestFoo) -> i32 { foo.x }
}

#attribute("test")
fn callMemberFunctionDirectly() {
    const instance = MemberFnTestFoo { .x = 1234, };
    const result = MemberFnTestFoo.member(instance);
    assert(result == 1234);
}

#attribute("test")
fn memberFunctions() {
    const r = MemberFnRand {.seed = 1234};
    assert(r.getSeed() == 1234);
}
struct MemberFnRand {
    seed: u32,
    pub fn getSeed(r: MemberFnRand) -> u32 {
        r.seed
    }
}

#attribute("test")
fn staticFunctionEvaluation() {
    assert(statically_added_number == 3);
}
const statically_added_number = staticAdd(1, 2);
fn staticAdd(a: i32, b: i32) -> i32 { a + b }


#attribute("test")
fn staticallyInitalizedList() {
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


#attribute("test")
fn staticEvalRecursive() {
    assert(seventh_fib_number == 21);
}
const seventh_fib_number = fibbonaci(7);
fn fibbonaci(x: i32) -> i32 {
    if (x <= 1) return 1;
    return fibbonaci(x - 1) + fibbonaci(x - 2);
}

#attribute("test")
fn staticEvalWhile() {
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

#attribute("test")
fn staticEvalListInit() {
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


#attribute("test")
fn genericFnWithImplicitCast() {
    assert(getFirstByte(u8, []u8 {13}) == 13);
    assert(getFirstByte(u16, []u16 {0, 13}) == 0);
}
fn getByte(ptr: ?&u8) -> u8 {*??ptr}
fn getFirstByte(inline T: type, mem: []T) -> u8 {
    getByte((&u8)(&mem[0]))
}

#attribute("test")
fn continueAndBreak() {
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


#attribute("test")
fn pointerDereferencing() {
    var x = i32(3);
    const y = &x;

    *y += 1;

    assert(x == 4);
    assert(*y == 4);
}

#attribute("test")
fn constantExpressions() {
    var array : [array_size]u8 = undefined;
    assert(@sizeOf(@typeOf(array)) == 20);
}
const array_size : u8 = 20;


#attribute("test")
fn minValueAndMaxValue() {
    assert(@maxValue(u8) == 255);
    assert(@maxValue(u16) == 65535);
    assert(@maxValue(u32) == 4294967295);
    assert(@maxValue(u64) == 18446744073709551615);

    assert(@maxValue(i8) == 127);
    assert(@maxValue(i16) == 32767);
    assert(@maxValue(i32) == 2147483647);
    assert(@maxValue(i64) == 9223372036854775807);

    assert(@minValue(u8) == 0);
    assert(@minValue(u16) == 0);
    assert(@minValue(u32) == 0);
    assert(@minValue(u64) == 0);

    assert(@minValue(i8) == -128);
    assert(@minValue(i16) == -32768);
    assert(@minValue(i32) == -2147483648);
    assert(@minValue(i64) == -9223372036854775808);
}

#attribute("test")
fn overflowIntrinsics() {
    var result: u8 = undefined;
    assert(@addWithOverflow(u8, 250, 100, &result));
    assert(!@addWithOverflow(u8, 100, 150, &result));
    assert(result == 250);
}


#attribute("test")
fn nestedArrays() {
    const array_of_strings = [][]u8 {"hello", "this", "is", "my", "thing"};
    for (array_of_strings) |s, i| {
        if (i == 0) assert(str.eql(s, "hello"));
        if (i == 1) assert(str.eql(s, "this"));
        if (i == 2) assert(str.eql(s, "is"));
        if (i == 3) assert(str.eql(s, "my"));
        if (i == 4) assert(str.eql(s, "thing"));
    }
}

#attribute("test")
fn intToPtrCast() {
    const x = isize(13);
    const y = (&u8)(x);
    const z = usize(y);
    assert(z == 13);
}

#attribute("test")
fn stringConcatenation() {
    assert(str.eql("OK" ++ " IT " ++ "WORKED", "OK IT WORKED"));
}

#attribute("test")
fn constantStructWithNegation() {
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


#attribute("test")
fn returnWithImplicitCastFromWhileLoop() {
    %%returnWithImplicitCastFromWhileLoopTest();
}
fn returnWithImplicitCastFromWhileLoopTest() -> %void {
    while (true) {
        return;
    }
}

#attribute("test")
fn returnStructByvalFromFunction() {
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

#attribute("test")
fn functionPointers() {
    const fns = []@typeOf(fn1) { fn1, fn2, fn3, fn4, };
    for (fns) |f, i| {
        assert(f() == u32(i) + 5);
    }
}
fn fn1() -> u32 {5}
fn fn2() -> u32 {6}
fn fn3() -> u32 {7}
fn fn4() -> u32 {8}



#attribute("test")
fn staticallyInitalizedStruct() {
    st_init_str_foo.x += 1;
    assert(st_init_str_foo.x == 14);
}
struct StInitStrFoo {
    x: i32,
    y: bool,
}
var st_init_str_foo = StInitStrFoo { .x = 13, .y = true, };

#attribute("test")
fn staticallyInitializedArrayLiteral() {
    const y : [4]u8 = st_init_arr_lit_x;
    assert(y[3] == 4);
}
const st_init_arr_lit_x = []u8{1,2,3,4};



#attribute("test")
fn pointerToVoidReturnType() {
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


#attribute("test")
fn callResultOfIfElseExpression() {
    assert(str.eql(f2(true), "a"));
    assert(str.eql(f2(false), "b"));
}
fn f2(x: bool) -> []u8 {
    return (if (x) fA else fB)();
}
fn fA() -> []u8 { "a" }
fn fB() -> []u8 { "b" }


#attribute("test")
fn constExpressionEvalHandlingOfVariables() {
    var x = true;
    while (x) {
        x = false;
    }
}



#attribute("test")
fn constantEnumInitializationWithDifferingSizes() {
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
#static_eval_enable(false)
fn test3_1(f: Test3Foo) {
    switch (f) {
        Three => |pt| {
            assert(pt.x == 3);
            assert(pt.y == 4);
        },
        else => unreachable{},
    }
}
#static_eval_enable(false)
fn test3_2(f: Test3Foo) {
    switch (f) {
        Two => |x| {
            assert(x == 13);
        },
        else => unreachable{},
    }
}



#attribute("test")
fn pubEnum() {
    pubEnumTest(other.APubEnum.Two);
}
fn pubEnumTest(foo: other.APubEnum) {
    assert(foo == other.APubEnum.Two);
}


#attribute("test")
fn castWithImportedSymbol() {
    assert(other.size_t(42) == 42);
}


#attribute("test")
fn whileWithContinueExpr() {
    var sum: i32 = 0;
    {var i: i32 = 0; while (i < 10; i += 1) {
        if (i == 5) continue;
        sum += i;
    }}
    assert(sum == 40);
}


#attribute("test")
fn forLoopWithPointerElemVar() {
    const source = "abcdefg";
    var target: [source.len]u8 = undefined;
    @memcpy(&target[0], &source[0], source.len);
    mangleString(target);
    assert(str.eql(target, "bcdefgh"));
}
#static_eval_enable(false)
fn mangleString(s: []u8) {
    for (s) |*c| {
        *c += 1;
    }
}

#attribute("test")
fn emptyStructMethodCall() {
    const es = EmptyStruct{};
    assert(es.method() == 1234);
}
struct EmptyStruct {
    #static_eval_enable(false)
    fn method(es: EmptyStruct) -> i32 { 1234 }
}


#attribute("test")
fn @"weird function name"() { }


#attribute("test")
fn returnEmptyStructFromFn() {
    testReturnEmptyStructFromFn();
    testReturnEmptyStructFromFnNoeval();
}
struct EmptyStruct2 {}
fn testReturnEmptyStructFromFn() -> EmptyStruct2 {
    EmptyStruct2 {}
}
#static_eval_enable(false)
fn testReturnEmptyStructFromFnNoeval() -> EmptyStruct2 {
    EmptyStruct2 {}
}

#attribute("test")
fn passSliceOfEmptyStructToFn() {
    assert(testPassSliceOfEmptyStructToFn([]EmptyStruct2{ EmptyStruct2{} }) == 1);
}
fn testPassSliceOfEmptyStructToFn(slice: []EmptyStruct2) -> usize {
    slice.len
}


#attribute("test")
fn pointerComparison() {
    const a = ([]u8)("a");
    const b = &a;
    assert(ptrEql(b, b));
}
fn ptrEql(a: &[]u8, b: &[]u8) -> bool {
    a == b
}

#attribute("test")
fn characterLiterals() {
    assert('\'' == single_quote);
}
const single_quote = '\'';


#attribute("test")
fn switchWithMultipleExpressions() {
    const x: i32 = switch (returnsFive()) {
        1, 2, 3 => 1,
        4, 5, 6 => 2,
        else => 3,
    };
    assert(x == 2);
}
#static_eval_enable(false)
fn returnsFive() -> i32 { 5 }


#attribute("test")
fn switchOnErrorUnion() {
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
#static_eval_enable(false)
fn returnsTen() -> %i32 { 10 }


#attribute("test")
fn boolCmp() {
    assert(testBoolCmp(true, false) == false);
}
#static_eval_enable(false)
fn testBoolCmp(a: bool, b: bool) -> bool { a == b }


#attribute("test")
fn takeAddressOfParameter() {
    testTakeAddressOfParameter(12.34);
    testTakeAddressOfParameterNoeval(12.34);
}
fn testTakeAddressOfParameter(f: f32) {
    const f_ptr = &f;
    assert(*f_ptr == 12.34);
}
#static_eval_enable(false)
fn testTakeAddressOfParameterNoeval(f: f32) {
    const f_ptr = &f;
    assert(*f_ptr == 12.34);
}


#attribute("test")
fn arrayMultOperator() {
    assert(str.eql("ab" ** 5, "ababababab"));
}

#attribute("test")
fn stringEscapes() {
    assert(str.eql("\"", "\x22"));
    assert(str.eql("\'", "\x27"));
    assert(str.eql("\n", "\x0a"));
    assert(str.eql("\r", "\x0d"));
    assert(str.eql("\t", "\x09"));
    assert(str.eql("\\", "\x5c"));
    assert(str.eql("\u1234\u0069", "\xe1\x88\xb4\x69"));
}

#attribute("test")
fn ifVarMaybePointer() {
    assert(shouldBeAPlus1(Particle {.a = 14, .b = 1, .c = 1, .d = 1}) == 15);
}
#static_eval_enable(false)
fn shouldBeAPlus1(p: Particle) -> u64 {
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

#attribute("test")
fn assignToIfVarPtr() {
    var maybe_bool: ?bool = true;

    if (const *b ?= maybe_bool) {
        *b = false;
    }

    assert(??maybe_bool == false);
}

#attribute("test")
fn cmpxchg() {
    var x: i32 = 1234;
    while (!@cmpxchg(&x, 1234, 5678, AtomicOrder.SeqCst, AtomicOrder.SeqCst)) {}
    assert(x == 5678);
}

#attribute("test")
fn fence() {
    var x: i32 = 1234;
    @fence(AtomicOrder.SeqCst);
    x = 5678;
}

#attribute("test")
fn unsignedWrapping() {
    testUnsignedWrappingEval(@maxValue(u32));
    testUnsignedWrappingNoeval(@maxValue(u32));
}
fn testUnsignedWrappingEval(x: u32) {
    const zero = x +% 1;
    assert(zero == 0);
    const orig = zero -% 1;
    assert(orig == @maxValue(u32));
}
#static_eval_enable(false)
fn testUnsignedWrappingNoeval(x: u32) {
    const zero = x +% 1;
    assert(zero == 0);
    const orig = zero -% 1;
    assert(orig == @maxValue(u32));
}

#attribute("test")
fn signedWrapping() {
    testSignedWrappingEval(@maxValue(i32));
    testSignedWrappingNoeval(@maxValue(i32));
}
fn testSignedWrappingEval(x: i32) {
    const min_val = x +% 1;
    assert(min_val == @minValue(i32));
    const max_val = min_val -% 1;
    assert(max_val == @maxValue(i32));
}
#static_eval_enable(false)
fn testSignedWrappingNoeval(x: i32) {
    const min_val = x +% 1;
    assert(min_val == @minValue(i32));
    const max_val = min_val -% 1;
    assert(max_val == @maxValue(i32));
}

#attribute("test")
fn negationWrapping() {
    testNegationWrappingEval(@minValue(i16));
    testNegationWrappingNoeval(@minValue(i16));
}
fn testNegationWrappingEval(x: i16) {
    assert(x == -32768);
    const neg = -%x;
    assert(neg == -32768);
}
#static_eval_enable(false)
fn testNegationWrappingNoeval(x: i16) {
    assert(x == -32768);
    const neg = -%x;
    assert(neg == -32768);
}

#attribute("test")
fn shlWrapping() {
    testShlWrappingEval(@maxValue(u16));
    testShlWrappingNoeval(@maxValue(u16));
}
fn testShlWrappingEval(x: u16) {
    const shifted = x <<% 1;
    assert(shifted == 65534);
}
#static_eval_enable(false)
fn testShlWrappingNoeval(x: u16) {
    const shifted = x <<% 1;
    assert(shifted == 65534);
}

#attribute("test")
fn shlWithOverflow() {
    var result: u16 = undefined;
    assert(@shlWithOverflow(u16, 0b0010111111111111, 3, &result));
    assert(!@shlWithOverflow(u16, 0b0010111111111111, 2, &result));
    assert(result == 0b1011111111111100);
}

#attribute("test")
fn cStringConcatenation() {
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

#attribute("test")
fn genericStruct() {
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

#attribute("test")
fn castSliceToU8Slice() {
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

#attribute("test")
fn floatDivision() {
    assert(fdiv32(12.0, 3.0) == 4.0);
}
#static_eval_enable(false)
fn fdiv32(a: f32, b: f32) -> f32 {
    a / b
}

#attribute("test")
fn exactDivision() {
    assert(divExact(55, 11) == 5);
}
#static_eval_enable(false)
fn divExact(a: u32, b: u32) -> u32 {
    @divExact(a, b)
}

#attribute("test")
fn nullLiteralOutsideFunction() {
    const is_null = if (const _ ?= here_is_a_null_literal.context) false else true;
    assert(is_null);
}
struct SillyStruct {
    context: ?i32,
}
const here_is_a_null_literal = SillyStruct {
    .context = null,
};

#attribute("test")
fn truncate() {
    assert(testTruncate(0x10fd) == 0xfd);
}
#static_eval_enable(false)
fn testTruncate(x: u32) -> u8 {
    @truncate(u8, x)
}

#attribute("test")
fn constDeclsInStruct() {
    assert(GenericDataThing(3).count_plus_one == 4);
}
struct GenericDataThing(count: isize) {
    const count_plus_one = count + 1;
}

#attribute("test")
fn useGenericParamInGenericParam() {
    assert(aGenericFn(i32, 3, 4) == 7);
}
fn aGenericFn(inline T: type, inline a: T, b: T) -> T {
    return a + b;
}


#attribute("test")
fn namespaceDependsOnCompileVar() {
    if (some_namespace.a_bool) {
        assert(some_namespace.a_bool);
    } else {
        assert(!some_namespace.a_bool);
    }
}
const some_namespace = switch(@compileVar("os")) {
    linux => @import("a.zig"),
    else => @import("b.zig"),
};


#attribute("test")
fn unsigned64BitDivision() {
    const result = div(1152921504606846976, 34359738365);
    assert(result.quotient == 33554432);
    assert(result.remainder == 100663296);
}
#static_eval_enable(false)
fn div(a: u64, b: u64) -> DivResult {
    DivResult {
        .quotient = a / b,
        .remainder = a % b,
    }
}
struct DivResult {
    quotient: u64,
    remainder: u64,
}

#attribute("test")
fn intTypeBuiltin() {
    assert(@intType(true, 8) == i8);
    assert(@intType(true, 16) == i16);
    assert(@intType(true, 32) == i32);
    assert(@intType(true, 64) == i64);

    assert(@intType(false, 8) == u8);
    assert(@intType(false, 16) == u16);
    assert(@intType(false, 32) == u32);
    assert(@intType(false, 64) == u64);

    assert(i8.bit_count == 8);
    assert(i16.bit_count == 16);
    assert(i32.bit_count == 32);
    assert(i64.bit_count == 64);

    assert(i8.is_signed);
    assert(i16.is_signed);
    assert(i32.is_signed);
    assert(i64.is_signed);
    assert(isize.is_signed);

    assert(!u8.is_signed);
    assert(!u16.is_signed);
    assert(!u32.is_signed);
    assert(!u64.is_signed);
    assert(!usize.is_signed);

}

#attribute("test")
fn intToEnum() {
    testIntToEnumEval(3);
    testIntToEnumNoeval(3);
}
fn testIntToEnumEval(x: i32) {
    assert(IntToEnumNumber(x) == IntToEnumNumber.Three);
}
#static_eval_enable(false)
fn testIntToEnumNoeval(x: i32) {
    assert(IntToEnumNumber(x) == IntToEnumNumber.Three);
}
enum IntToEnumNumber {
    Zero,
    One,
    Two,
    Three,
    Four,
}

const std = @import("std");
const assert = std.debug.assert;
const str = std.str;
const cstr = std.cstr;


fn staticEvalListInit() {
    @setFnTest(this);

    assert(static_vec3.data[2] == 1.0);
}
const static_vec3 = vec3(0.0, 0.0, 1.0);
pub const Vec3 = struct {
    data: [3]f32,
};
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

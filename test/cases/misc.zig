const assert = @import("std").debug.assert;
const mem = @import("std").mem;
const cstr = @import("std").cstr;

// normal comment
/// this is a documentation comment
/// doc comment line 2
fn emptyFunctionWithComments() {
    @setFnTest(this);
}

export fn disabledExternFn() {
    @setFnVisible(this, false);
}

fn callDisabledExternFn() {
    @setFnTest(this);

    disabledExternFn();
}

fn intTypeBuiltin() {
    @setFnTest(this);

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

fn minValueAndMaxValue() {
    @setFnTest(this);

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

fn maxValueType() {
    @setFnTest(this);

    // If the type of @maxValue(i32) was i32 then this implicit cast to
    // u32 would not work. But since the value is a number literal,
    // it works fine.
    const x: u32 = @maxValue(i32);
    assert(x == 2147483647);
}

fn shortCircuit() {
    @setFnTest(this);
    testShortCircuit(false, true);
}

fn testShortCircuit(f: bool, t: bool) {
    var hit_1 = f;
    var hit_2 = f;
    var hit_3 = f;
    var hit_4 = f;

    if (t || {assert(f); f}) {
        hit_1 = t;
    }
    if (f || { hit_2 = t; f }) {
        assert(f);
    }

    if (t && { hit_3 = t; f }) {
        assert(f);
    }
    if (f && {assert(f); f}) {
        assert(f);
    } else {
        hit_4 = t;
    }
    assert(hit_1);
    assert(hit_2);
    assert(hit_3);
    assert(hit_4);
}

fn truncate() {
    @setFnTest(this);

    assert(testTruncate(0x10fd) == 0xfd);
}
fn testTruncate(x: u32) -> u8 {
    @truncate(u8, x)
}

fn assignToIfVarPtr() {
    @setFnTest(this);

    var maybe_bool: ?bool = true;

    if (const *b ?= maybe_bool) {
        *b = false;
    }

    assert(??maybe_bool == false);
}

fn first4KeysOfHomeRow() -> []const u8 {
    "aoeu"
}

fn ReturnStringFromFunction() {
    @setFnTest(this);

    assert(mem.eql(first4KeysOfHomeRow(), "aoeu"));
}

const g1 : i32 = 1233 + 1;
var g2 : i32 = 0;

fn globalVariables() {
    @setFnTest(this);

    assert(g2 == 0);
    g2 = g1;
    assert(g2 == 1234);
}


fn memcpyAndMemsetIntrinsics() {
    @setFnTest(this);

    var foo : [20]u8 = undefined;
    var bar : [20]u8 = undefined;

    @memset(&foo[0], 'A', foo.len);
    @memcpy(&bar[0], &foo[0], bar.len);

    if (bar[11] != 'A') @unreachable();
}

fn builtinStaticEval() {
    @setFnTest(this);

    const x : i32 = comptime {1 + 2 + 3};
    assert(x == comptime 6);
}

fn slicing() {
    @setFnTest(this);

    var array : [20]i32 = undefined;

    array[5] = 1234;

    var slice = array[5...10];

    if (slice.len != 5) @unreachable();

    const ptr = &slice[0];
    if (ptr[0] != 1234) @unreachable();

    var slice_rest = array[10...];
    if (slice_rest.len != 10) @unreachable();
}


fn constantEqualFunctionPointers() {
    @setFnTest(this);

    const alias = emptyFn;
    assert(comptime {emptyFn == alias});
}

fn emptyFn() {}


fn hexEscape() {
    @setFnTest(this);

    assert(mem.eql("\x68\x65\x6c\x6c\x6f", "hello"));
}

fn stringConcatenation() {
    @setFnTest(this);

    assert(mem.eql("OK" ++ " IT " ++ "WORKED", "OK IT WORKED"));
}

fn arrayMultOperator() {
    @setFnTest(this);

    assert(mem.eql("ab" ** 5, "ababababab"));
}

fn stringEscapes() {
    @setFnTest(this);

    assert(mem.eql("\"", "\x22"));
    assert(mem.eql("\'", "\x27"));
    assert(mem.eql("\n", "\x0a"));
    assert(mem.eql("\r", "\x0d"));
    assert(mem.eql("\t", "\x09"));
    assert(mem.eql("\\", "\x5c"));
    assert(mem.eql("\u1234\u0069", "\xe1\x88\xb4\x69"));
}

fn multilineString() {
    @setFnTest(this);

    const s1 =
        \\one
        \\two)
        \\three
    ;
    const s2 = "one\ntwo)\nthree";
    assert(mem.eql(s1, s2));
}

fn multilineCString() {
    @setFnTest(this);

    const s1 =
        c\\one
        c\\two)
        c\\three
    ;
    const s2 = c"one\ntwo)\nthree";
    assert(cstr.cmp(s1, s2) == 0);
}


fn typeEquality() {
    @setFnTest(this);

    assert(&const u8 != &u8);
}


const global_a: i32 = 1234;
const global_b: &const i32 = &global_a;
const global_c: &const f32 = (&const f32)(global_b);
fn compileTimeGlobalReinterpret() {
    @setFnTest(this);
    const d = (&const i32)(global_c);
    assert(*d == 1234);
}

fn explicitCastMaybePointers() {
    @setFnTest(this);

    const a: ?&i32 = undefined;
    const b: ?&f32 = (?&f32)(a);
}

fn genericMallocFree() {
    @setFnTest(this);

    const a = %%memAlloc(u8, 10);
    memFree(u8, a);
}
const some_mem : [100]u8 = undefined;
fn memAlloc(comptime T: type, n: usize) -> %[]T {
    return (&T)(&some_mem[0])[0...n];
}
fn memFree(comptime T: type, memory: []T) { }


fn castUndefined() {
    @setFnTest(this);

    const array: [100]u8 = undefined;
    const slice = ([]u8)(array);
    testCastUndefined(slice);
}
fn testCastUndefined(x: []const u8) {}


fn castSmallUnsignedToLargerSigned() {
    @setFnTest(this);

    assert(castSmallUnsignedToLargerSigned1(200) == i16(200));
    assert(castSmallUnsignedToLargerSigned2(9999) == i64(9999));
}
fn castSmallUnsignedToLargerSigned1(x: u8) -> i16 { x }
fn castSmallUnsignedToLargerSigned2(x: u16) -> i64 { x }


fn implicitCastAfterUnreachable() {
    @setFnTest(this);

    assert(outer() == 1234);
}
fn inner() -> i32 { 1234 }
fn outer() -> i64 {
    return inner();
}


fn pointerDereferencing() {
    @setFnTest(this);

    var x = i32(3);
    const y = &x;

    *y += 1;

    assert(x == 4);
    assert(*y == 4);
}

fn callResultOfIfElseExpression() {
    @setFnTest(this);

    assert(mem.eql(f2(true), "a"));
    assert(mem.eql(f2(false), "b"));
}
fn f2(x: bool) -> []u8 {
    return (if (x) fA else fB)();
}
fn fA() -> []u8 { "a" }
fn fB() -> []u8 { "b" }


fn constExpressionEvalHandlingOfVariables() {
    @setFnTest(this);

    var x = true;
    while (x) {
        x = false;
    }
}



fn constantEnumInitializationWithDifferingSizes() {
    @setFnTest(this);

    test3_1(test3_foo);
    test3_2(test3_bar);
}
const Test3Foo = enum {
    One,
    Two: f32,
    Three: Test3Point,
};
const Test3Point = struct {
    x: i32,
    y: i32,
};
const test3_foo = Test3Foo.Three{Test3Point {.x = 3, .y = 4}};
const test3_bar = Test3Foo.Two{13};
fn test3_1(f: Test3Foo) {
    switch (f) {
        Test3Foo.Three => |pt| {
            assert(pt.x == 3);
            assert(pt.y == 4);
        },
        else => @unreachable(),
    }
}
fn test3_2(f: Test3Foo) {
    switch (f) {
        Test3Foo.Two => |x| {
            assert(x == 13);
        },
        else => @unreachable(),
    }
}


fn characterLiterals() {
    @setFnTest(this);

    assert('\'' == single_quote);
}
const single_quote = '\'';



fn takeAddressOfParameter() {
    @setFnTest(this);

    testTakeAddressOfParameter(12.34);
}
fn testTakeAddressOfParameter(f: f32) {
    const f_ptr = &f;
    assert(*f_ptr == 12.34);
}


fn intToPtrCast() {
    @setFnTest(this);

    const x = isize(13);
    const y = (&u8)(x);
    const z = usize(y);
    assert(z == 13);
}


fn pointerComparison() {
    @setFnTest(this);

    const a = ([]u8)("a");
    const b = &a;
    assert(ptrEql(b, b));
}
fn ptrEql(a: &[]const u8, b: &[]const u8) -> bool {
    a == b
}


fn cStringConcatenation() {
    @setFnTest(this);

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

fn castSliceToU8Slice() {
    @setFnTest(this);

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

fn pointerToVoidReturnType() {
    @setFnTest(this);

    %%testPointerToVoidReturnType();
}
fn testPointerToVoidReturnType() -> %void {
    const a = testPointerToVoidReturnType2();
    return *a;
}
const test_pointer_to_void_return_type_x = void{};
fn testPointerToVoidReturnType2() -> &const void {
    return &test_pointer_to_void_return_type_x;
}


fn nonConstPtrToAliasedType() {
    @setFnTest(this);
    const int = i32;
    assert(?&int == ?&i32);
}



fn array2DConstDoublePtr() {
    @setFnTest(this);

    const rect_2d_vertexes = [][1]f32 {
        []f32{1.0},
        []f32{2.0},
    };
    testArray2DConstDoublePtr(&rect_2d_vertexes[0][0]);
}

fn testArray2DConstDoublePtr(ptr: &const f32) {
    assert(ptr[0] == 1.0);
    assert(ptr[1] == 2.0);
}

fn isInteger() {
    @setFnTest(this);

    comptime {
        assert(@isInteger(i8));
        assert(@isInteger(u8));
        assert(@isInteger(i64));
        assert(@isInteger(u64));
        assert(!@isInteger(f32));
        assert(!@isInteger(f64));
        assert(!@isInteger(bool));
        assert(!@isInteger(&i32));
    }
}

fn isFloat() {
    @setFnTest(this);

    comptime {
        assert(!@isFloat(i8));
        assert(!@isFloat(u8));
        assert(!@isFloat(i64));
        assert(!@isFloat(u64));
        assert(@isFloat(f32));
        assert(@isFloat(f64));
        assert(!@isFloat(bool));
        assert(!@isFloat(&f32));
    }
}

fn canImplicitCast() {
    @setFnTest(this);

    comptime {
        assert(@canImplicitCast(i64, i32(3)));
        assert(!@canImplicitCast(i32, f32(1.234)));
        assert(@canImplicitCast([]const u8, "aoeu"));
    }
}

fn typeName() {
    @setFnTest(this);

    comptime {
        assert(mem.eql(@typeName(i64), "i64"));
        assert(mem.eql(@typeName(&usize), "&usize"));
    }
}

fn volatileLoadAndStore() {
    @setFnTest(this);

    var number: i32 = 1234;
    const ptr = &volatile number;
    *ptr += 1;
    assert(*ptr == 1235);
}

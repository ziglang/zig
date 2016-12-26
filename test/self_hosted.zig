// TODO not passing
fn genericFnWithImplicitCast() {
    @setFnTest(this);

    assert(getFirstByte(u8, []u8 {13}) == 13);
    assert(getFirstByte(u16, []u16 {0, 13}) == 0);
}
fn getByte(ptr: ?&u8) -> u8 {*??ptr}
fn getFirstByte(inline T: type, mem: []T) -> u8 {
    getByte((&u8)(&mem[0]))
}


// TODO not passing
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


// TODO not passing (goes in struct.zig)
fn passSliceOfEmptyStructToFn() {
    @setFnTest(this);

    assert(testPassSliceOfEmptyStructToFn([]EmptyStruct2{ EmptyStruct2{} }) == 1);
}
fn testPassSliceOfEmptyStructToFn(slice: []EmptyStruct2) -> usize {
    slice.len
}


// TODO change this test to an issue
// we're going to change how this works
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

// TODO not passing
fn cStringConcatenation() {
    @setFnTest(this, true);

    const a = c"OK" ++ c" IT " ++ c"WORKED";
    const b = c"OK IT WORKED";

    const len = cstrlen(b);
    const len_with_null = len + 1;
    {var i: u32 = 0; while (i < len_with_null; i += 1) {
        assert(a[i] == b[i]);
    }}
    assert(a[len] == 0);
    assert(b[len] == 0);
}

// TODO not passing
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

// TODO not passing
fn intToEnum() {
    @setFnTest(this);

    testIntToEnumEval(3);
}
fn testIntToEnumEval(x: i32) {
    assert(IntToEnumNumber(x) == IntToEnumNumber.Three);
}
const IntToEnumNumber = enum {
    Zero,
    One,
    Two,
    Three,
    Four,
};

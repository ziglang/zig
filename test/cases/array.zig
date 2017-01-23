const assert = @import("std").debug.assert;
const str = @import("std").str;

fn arrays() {
    @setFnTest(this);

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

fn voidArrays() {
    @setFnTest(this);

    var array: [4]void = undefined;
    array[0] = void{};
    array[1] = array[2];
    assert(@sizeOf(@typeOf(array)) == 0);
    assert(array.len == 4);
}

fn arrayLiteral() {
    @setFnTest(this);

    const hex_mult = []u16{4096, 256, 16, 1};

    assert(hex_mult.len == 4);
    assert(hex_mult[1] == 256);
}

fn arrayDotLenConstExpr() {
    @setFnTest(this);

    assert(comptime {some_array.len == 4});
}

const ArrayDotLenConstExpr = struct {
    y: [some_array.len]u8,
};
const some_array = []u8 {0, 1, 2, 3};


fn nestedArrays() {
    @setFnTest(this);

    const array_of_strings = [][]u8 {"hello", "this", "is", "my", "thing"};
    for (array_of_strings) |s, i| {
        if (i == 0) assert(str.eql(s, "hello"));
        if (i == 1) assert(str.eql(s, "this"));
        if (i == 2) assert(str.eql(s, "is"));
        if (i == 3) assert(str.eql(s, "my"));
        if (i == 4) assert(str.eql(s, "thing"));
    }
}

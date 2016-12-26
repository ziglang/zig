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

    assert(@staticEval(some_array.len) == 4);
}

const ArrayDotLenConstExpr = struct {
    y: [some_array.len]u8,
};
const some_array = []u8 {0, 1, 2, 3};


fn nestedArrays() {
    @setFnTest(this);

    const array_of_strings = [][]u8 {"hello", "this", "is", "my", "thing"};
    for (array_of_strings) |s, i| {
        if (i == 0) assert(memeql(s, "hello"));
        if (i == 1) assert(memeql(s, "this"));
        if (i == 2) assert(memeql(s, "is"));
        if (i == 3) assert(memeql(s, "my"));
        if (i == 4) assert(memeql(s, "thing"));
    }
}



// TODO const assert = @import("std").debug.assert;
fn assert(ok: bool) {
    if (!ok)
        @unreachable();
}

// TODO import from std.str
pub fn memeql(a: []const u8, b: []const u8) -> bool {
    sliceEql(u8, a, b)
}

// TODO import from std.str
pub fn sliceEql(inline T: type, a: []const T, b: []const T) -> bool {
    if (a.len != b.len) return false;
    for (a) |item, index| {
        if (b[index] != item) return false;
    }
    return true;
}

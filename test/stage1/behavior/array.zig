const assertOrPanic = @import("std").debug.assertOrPanic;
const mem = @import("std").mem;

test "arrays" {
    var array: [5]u32 = undefined;

    var i: u32 = 0;
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

    assertOrPanic(accumulator == 15);
    assertOrPanic(getArrayLen(array) == 5);
}
fn getArrayLen(a: []const u32) usize {
    return a.len;
}

test "void arrays" {
    var array: [4]void = undefined;
    array[0] = void{};
    array[1] = array[2];
    assertOrPanic(@sizeOf(@typeOf(array)) == 0);
    assertOrPanic(array.len == 4);
}

test "array literal" {
    const hex_mult = []u16{
        4096,
        256,
        16,
        1,
    };

    assertOrPanic(hex_mult.len == 4);
    assertOrPanic(hex_mult[1] == 256);
}

test "array dot len const expr" {
    assertOrPanic(comptime x: {
        break :x some_array.len == 4;
    });
}

const ArrayDotLenConstExpr = struct {
    y: [some_array.len]u8,
};
const some_array = []u8{
    0,
    1,
    2,
    3,
};

test "nested arrays" {
    const array_of_strings = [][]const u8{
        "hello",
        "this",
        "is",
        "my",
        "thing",
    };
    for (array_of_strings) |s, i| {
        if (i == 0) assertOrPanic(mem.eql(u8, s, "hello"));
        if (i == 1) assertOrPanic(mem.eql(u8, s, "this"));
        if (i == 2) assertOrPanic(mem.eql(u8, s, "is"));
        if (i == 3) assertOrPanic(mem.eql(u8, s, "my"));
        if (i == 4) assertOrPanic(mem.eql(u8, s, "thing"));
    }
}

var s_array: [8]Sub = undefined;
const Sub = struct {
    b: u8,
};
const Str = struct {
    a: []Sub,
};
test "set global var array via slice embedded in struct" {
    var s = Str{ .a = s_array[0..] };

    s.a[0].b = 1;
    s.a[1].b = 2;
    s.a[2].b = 3;

    assertOrPanic(s_array[0].b == 1);
    assertOrPanic(s_array[1].b == 2);
    assertOrPanic(s_array[2].b == 3);
}

test "array literal with specified size" {
    var array = [2]u8{
        1,
        2,
    };
    assertOrPanic(array[0] == 1);
    assertOrPanic(array[1] == 2);
}

test "array child property" {
    var x: [5]i32 = undefined;
    assertOrPanic(@typeOf(x).Child == i32);
}

test "array len property" {
    var x: [5]i32 = undefined;
    assertOrPanic(@typeOf(x).len == 5);
}

test "array len field" {
    var arr = [4]u8{ 0, 0, 0, 0 };
    var ptr = &arr;
    assertOrPanic(arr.len == 4);
    comptime assertOrPanic(arr.len == 4);
    assertOrPanic(ptr.len == 4);
    comptime assertOrPanic(ptr.len == 4);
}

test "single-item pointer to array indexing and slicing" {
    testSingleItemPtrArrayIndexSlice();
    comptime testSingleItemPtrArrayIndexSlice();
}

fn testSingleItemPtrArrayIndexSlice() void {
    var array = "aaaa";
    doSomeMangling(&array);
    assertOrPanic(mem.eql(u8, "azya", array));
}

fn doSomeMangling(array: *[4]u8) void {
    array[1] = 'z';
    array[2..3][0] = 'y';
}

test "implicit cast single-item pointer" {
    testImplicitCastSingleItemPtr();
    comptime testImplicitCastSingleItemPtr();
}

fn testImplicitCastSingleItemPtr() void {
    var byte: u8 = 100;
    const slice = (*[1]u8)(&byte)[0..];
    slice[0] += 1;
    assertOrPanic(byte == 101);
}

fn testArrayByValAtComptime(b: [2]u8) u8 {
    return b[0];
}

test "comptime evalutating function that takes array by value" {
    const arr = []u8{ 0, 1 };
    _ = comptime testArrayByValAtComptime(arr);
    _ = comptime testArrayByValAtComptime(arr);
}

test "implicit comptime in array type size" {
    var arr: [plusOne(10)]bool = undefined;
    assertOrPanic(arr.len == 11);
}

fn plusOne(x: u32) u32 {
    return x + 1;
}

test "array literal as argument to function" {
    const S = struct {
        fn entry(two: i32) void {
            foo([]i32{
                1,
                2,
                3,
            });
            foo([]i32{
                1,
                two,
                3,
            });
            foo2(true, []i32{
                1,
                2,
                3,
            });
            foo2(true, []i32{
                1,
                two,
                3,
            });
        }
        fn foo(x: []const i32) void {
            assertOrPanic(x[0] == 1);
            assertOrPanic(x[1] == 2);
            assertOrPanic(x[2] == 3);
        }
        fn foo2(trash: bool, x: []const i32) void {
            assertOrPanic(trash);
            assertOrPanic(x[0] == 1);
            assertOrPanic(x[1] == 2);
            assertOrPanic(x[2] == 3);
        }
    };
    S.entry(2);
    comptime S.entry(2);
}

test "double nested array to const slice cast in array literal" {
    const S = struct {
        fn entry(two: i32) void {
            const cases = [][]const []const i32{
                [][]const i32{[]i32{1}},
                [][]const i32{[]i32{ 2, 3 }},
                [][]const i32{
                    []i32{4},
                    []i32{ 5, 6, 7 },
                },
            };
            check(cases);

            const cases2 = [][]const i32{
                []i32{1},
                []i32{ two, 3 },
            };
            assertOrPanic(cases2.len == 2);
            assertOrPanic(cases2[0].len == 1);
            assertOrPanic(cases2[0][0] == 1);
            assertOrPanic(cases2[1].len == 2);
            assertOrPanic(cases2[1][0] == 2);
            assertOrPanic(cases2[1][1] == 3);

            const cases3 = [][]const []const i32{
                [][]const i32{[]i32{1}},
                [][]const i32{[]i32{ two, 3 }},
                [][]const i32{
                    []i32{4},
                    []i32{ 5, 6, 7 },
                },
            };
            check(cases3);
        }

        fn check(cases: []const []const []const i32) void {
            assertOrPanic(cases.len == 3);
            assertOrPanic(cases[0].len == 1);
            assertOrPanic(cases[0][0].len == 1);
            assertOrPanic(cases[0][0][0] == 1);
            assertOrPanic(cases[1].len == 1);
            assertOrPanic(cases[1][0].len == 2);
            assertOrPanic(cases[1][0][0] == 2);
            assertOrPanic(cases[1][0][1] == 3);
            assertOrPanic(cases[2].len == 2);
            assertOrPanic(cases[2][0].len == 1);
            assertOrPanic(cases[2][0][0] == 4);
            assertOrPanic(cases[2][1].len == 3);
            assertOrPanic(cases[2][1][0] == 5);
            assertOrPanic(cases[2][1][1] == 6);
            assertOrPanic(cases[2][1][2] == 7);
        }
    };
    S.entry(2);
    comptime S.entry(2);
}

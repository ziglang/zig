pub inline fn swapIfLe(comptime T: type, x: T) -> T {
    swapIf(false, T, x)
}

pub inline fn swapIfBe(comptime T: type, x: T) -> T {
    swapIf(true, T, x)
}

pub inline fn swapIf(is_be: bool, comptime T: type, x: T) -> T {
    if (@compileVar("is_big_endian") == is_be) swap(T, x) else x
}

pub fn swap(comptime T: type, x: T) -> T {
    const x_slice = ([]u8)((&const x)[0...1]);
    var result: T = undefined;
    const result_slice = ([]u8)((&result)[0...1]);
    for (result_slice) |*b, i| {
        *b = x_slice[@sizeOf(T) - i - 1];
    }
    return result;
}

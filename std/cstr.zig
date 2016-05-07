// TODO fix https://github.com/andrewrk/zig/issues/140
// and then make this able to run at compile time
#static_eval_enable(false)
pub fn len(ptr: &const u8) -> isize {
    var count: isize = 0;
    while (ptr[count] != 0; count += 1) {}
    return count;
}

// TODO fix https://github.com/andrewrk/zig/issues/140
// and then make this able to run at compile time
#static_eval_enable(false)
pub fn cmp(a: &const u8, b: &const u8) -> i32 {
    var index: isize = 0;
    while (a[index] == b[index] && a[index] != 0; index += 1) {}
    return a[index] - b[index];
}

pub fn to_slice_const(str: &const u8) -> []const u8 {
    return str[0...len(str)];
}

pub fn to_slice(str: &u8) -> []u8 {
    return str[0...len(str)];
}


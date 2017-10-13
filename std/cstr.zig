const debug = @import("debug.zig");
const mem = @import("mem.zig");
const assert = debug.assert;

pub fn len(ptr: &const u8) -> usize {
    var count: usize = 0;
    while (ptr[count] != 0) : (count += 1) {}
    return count;
}

pub fn cmp(a: &const u8, b: &const u8) -> i8 {
    var index: usize = 0;
    while (a[index] == b[index] and a[index] != 0) : (index += 1) {}
    if (a[index] > b[index]) {
        return 1;
    } else if (a[index] < b[index]) {
        return -1;
    } else {
        return 0;
    };
}

pub fn toSliceConst(str: &const u8) -> []const u8 {
    return str[0..len(str)];
}

pub fn toSlice(str: &u8) -> []u8 {
    return str[0..len(str)];
}

test "cstr fns" {
    comptime testCStrFnsImpl();
    testCStrFnsImpl();
}

fn testCStrFnsImpl() {
    assert(cmp(c"aoeu", c"aoez") == -1);
    assert(len(c"123456789") == 9);
}

/// Returns a mutable slice with exactly the same size which is guaranteed to
/// have a null byte after it.
/// Caller owns the returned memory.
pub fn addNullByte(allocator: &mem.Allocator, slice: []const u8) -> %[]u8 {
    const result = %return allocator.alloc(u8, slice.len + 1);
    mem.copy(u8, result, slice);
    result[slice.len] = 0;
    return result[0..slice.len];
}

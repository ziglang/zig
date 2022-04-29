const array = [_]u8{};
export fn foo() void {
    var index: usize = 0;
    const pointer = &array[index];
    _ = pointer;
}

// error
// backend=stage1
// target=native
//
// tmp.zig:4:27: error: accessing a zero length array is not allowed

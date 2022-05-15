const array = [_]u8{};
export fn foo() void {
    const pointer = &array[0];
    _ = pointer;
}

// error
// backend=stage1
// target=native
//
// tmp.zig:3:27: error: accessing a zero length array is not allowed

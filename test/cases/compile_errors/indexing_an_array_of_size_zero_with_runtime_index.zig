const array = [_]u8{};
export fn foo() void {
    var index: usize = 0;
    _ = &index;
    const pointer = &array[index];
    _ = pointer;
}

// error
//
// :5:27: error: indexing into empty array is not allowed

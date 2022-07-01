const array = [_]u8{};
export fn foo() void {
    var index: usize = 0;
    const pointer = &array[index];
    _ = pointer;
}

// error
// backend=stage2
// target=native
//
// :4:27: error: indexing into empty array is not allowed

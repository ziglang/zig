const array = [_]u8{};
export fn foo() void {
    const pointer = &array[0];
    _ = pointer;
}

// error
// backend=stage2
// target=native
//
// :3:27: error: indexing into empty array is not allowed

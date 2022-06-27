export fn entry(ptr: *i32) void {
    const slice = ptr[0..2];
    _ = slice;
}

// error
// backend=stage2
// target=native
//
// :2:22: error: slice of single-item pointer

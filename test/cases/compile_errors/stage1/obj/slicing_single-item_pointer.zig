export fn entry(ptr: *i32) void {
    const slice = ptr[0..2];
    _ = slice;
}

// error
// backend=stage1
// target=native
//
// tmp.zig:2:22: error: slice of single-item pointer

export fn entry(ptr: *i32) void {
    const slice = ptr[0..2];
    _ = slice;
}

// slicing single-item pointer
//
// tmp.zig:2:22: error: slice of single-item pointer

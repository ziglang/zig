export fn entry(ptr: *i32) i32 {
    return ptr[1];
}

// error
// backend=stage1
// target=native
//
// tmp.zig:2:15: error: index of single-item pointer

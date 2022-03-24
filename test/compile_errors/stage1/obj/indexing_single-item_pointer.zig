export fn entry(ptr: *i32) i32 {
    return ptr[1];
}

// indexing single-item pointer
//
// tmp.zig:2:15: error: index of single-item pointer

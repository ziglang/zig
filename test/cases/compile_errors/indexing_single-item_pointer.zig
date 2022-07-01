export fn entry(ptr: *i32) i32 {
    return ptr[1];
}

// error
// backend=stage2
// target=native
//
// :2:15: error: element access of non-indexable type '*i32'

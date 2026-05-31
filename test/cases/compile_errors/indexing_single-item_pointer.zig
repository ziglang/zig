export fn entry(ptr: *i32) i32 {
    return ptr[1];
}

// error
//
// :2:15: error: type '*i32' does not support indexing
// :2:15: note: operand must be an array, slice, tuple, or vector

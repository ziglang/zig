export fn entry(x: i32) usize {
    return @ptrToInt(x);
}

// non pointer given to @ptrToInt
//
// tmp.zig:2:22: error: expected pointer, found 'i32'

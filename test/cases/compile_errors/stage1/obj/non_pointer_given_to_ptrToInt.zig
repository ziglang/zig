export fn entry(x: i32) usize {
    return @ptrToInt(x);
}

// error
// backend=stage1
// target=native
//
// tmp.zig:2:22: error: expected pointer, found 'i32'

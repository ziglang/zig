export fn entry(x: i32) usize {
    return @ptrToInt(x);
}

// error
// backend=stage2
// target=native
//
// :2:22: error: expected pointer, found 'i32'

export fn entry(x: i32) usize {
    return @intFromPtr(x);
}

// error
// backend=stage2
// target=native
//
// :2:24: error: expected pointer, found 'i32'

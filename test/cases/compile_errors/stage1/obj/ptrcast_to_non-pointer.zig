export fn entry(a: *i32) usize {
    return @ptrCast(usize, a);
}

// error
// backend=stage1
// target=native
//
// tmp.zig:2:21: error: expected pointer, found 'usize'

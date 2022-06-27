export fn entry(a: *i32) usize {
    return @ptrCast(usize, a);
}

// error
// backend=stage2
// target=native
//
// :2:21: error: expected pointer type, found 'usize'

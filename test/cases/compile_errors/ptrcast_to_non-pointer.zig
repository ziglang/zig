export fn entry(a: *i32) usize {
    return @ptrCast(a);
}

// error
// backend=stage2
// target=native
//
// :2:12: error: expected pointer type, found 'usize'

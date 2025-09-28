export fn entry(a: *i32) usize {
    return @ptrCast(a);
}

// error
//
// :2:12: error: expected pointer type, found 'usize'

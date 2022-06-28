export fn entry(a: *i32) usize {
    return @ptrCast(usize, a);
}

// error
// backend=llvm
// target=native
//
// :2:21: error: expected pointer type, found 'usize'

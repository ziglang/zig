export fn entry(a: *i32) usize {
    return @ptrCast(usize, a);
}

// ptrcast to non-pointer
//
// tmp.zig:2:21: error: expected pointer, found 'usize'

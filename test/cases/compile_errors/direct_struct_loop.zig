const A = struct {
    a: A,
};
export fn entry() usize {
    return @sizeOf(A);
}

// error
// backend=stage2
// target=native
//
// :1:11: error: struct 'tmp.A' depends on itself
// :2:5: note: while checking this field

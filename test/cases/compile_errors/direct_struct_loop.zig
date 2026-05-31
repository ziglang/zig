const A = struct {
    a: A,
};
export fn entry() usize {
    return @sizeOf(A);
}

// error
//
// :1:11: error: struct 'tmp.A' depends on itself

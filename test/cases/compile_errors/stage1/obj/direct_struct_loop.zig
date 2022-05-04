const A = struct { a : A, };
export fn entry() usize { return @sizeOf(A); }

// error
// backend=stage1
// target=native
//
// tmp.zig:1:11: error: struct 'A' depends on itself

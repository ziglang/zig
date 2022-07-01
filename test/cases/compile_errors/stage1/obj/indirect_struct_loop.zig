const A = struct { b : B, };
const B = struct { c : C, };
const C = struct { a : A, };
export fn entry() usize { return @sizeOf(A); }

// error
// backend=stage1
// target=native
//
// tmp.zig:1:11: error: struct 'A' depends on itself

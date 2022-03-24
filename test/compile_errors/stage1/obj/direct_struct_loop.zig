const A = struct { a : A, };
export fn entry() usize { return @sizeOf(A); }

// direct struct loop
//
// tmp.zig:1:11: error: struct 'A' depends on itself

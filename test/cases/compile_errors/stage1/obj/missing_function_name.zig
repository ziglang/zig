fn () void {}
export fn entry() usize { return @sizeOf(@TypeOf(f)); }

// error
// backend=stage1
// target=native
//
// tmp.zig:1:1: error: missing function name

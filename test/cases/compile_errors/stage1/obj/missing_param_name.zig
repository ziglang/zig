fn f(i32) void {}
export fn entry() usize { return @sizeOf(@TypeOf(f)); }

// error
// backend=stage1
// target=native
//
// tmp.zig:1:6: error: missing parameter name

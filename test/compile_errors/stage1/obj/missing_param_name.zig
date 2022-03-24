fn f(i32) void {}
export fn entry() usize { return @sizeOf(@TypeOf(f)); }

// missing param name
//
// tmp.zig:1:6: error: missing parameter name

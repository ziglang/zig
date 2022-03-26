fn () void {}
export fn entry() usize { return @sizeOf(@TypeOf(f)); }

// missing function name
//
// tmp.zig:1:1: error: missing function name

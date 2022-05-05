const resource = @embedFile("bogus.txt",);

export fn entry() usize { return @sizeOf(@TypeOf(resource)); }

// error
// backend=stage1
// target=native
//
// tmp.zig:1:29: error: unable to find '

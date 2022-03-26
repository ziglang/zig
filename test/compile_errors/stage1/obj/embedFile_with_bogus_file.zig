const resource = @embedFile("bogus.txt",);

export fn entry() usize { return @sizeOf(@TypeOf(resource)); }

// @embedFile with bogus file
//
// tmp.zig:1:29: error: unable to find '

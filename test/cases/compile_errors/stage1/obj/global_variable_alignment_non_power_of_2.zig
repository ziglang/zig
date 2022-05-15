const some_data: [100]u8 align(3) = undefined;
export fn entry() usize { return @sizeOf(@TypeOf(some_data)); }

// error
// backend=stage1
// target=native
//
// tmp.zig:1:32: error: alignment value 3 is not a power of 2

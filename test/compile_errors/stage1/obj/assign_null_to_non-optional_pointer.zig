const a: *u8 = null;

export fn entry() usize { return @sizeOf(@TypeOf(a)); }

// error
// backend=stage1
// target=native
//
// tmp.zig:1:16: error: expected type '*u8', found '@Type(.Null)'

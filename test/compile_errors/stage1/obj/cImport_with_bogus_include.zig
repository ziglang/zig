const c = @cImport(@cInclude("bogus.h"));
export fn entry() usize { return @sizeOf(@TypeOf(c.bogo)); }

// error
// backend=stage1
// target=native
//
// tmp.zig:1:11: error: C import failed
// .h:1:10: note: 'bogus.h' file not found

const c = @cImport(@cInclude("bogus.h"));
export fn entry() usize { return @sizeOf(@TypeOf(c.bogo)); }

// error
// backend=llvm
// target=native
//
// :1:11: error: C import failed
// :1:10: error: 'bogus.h' file not found

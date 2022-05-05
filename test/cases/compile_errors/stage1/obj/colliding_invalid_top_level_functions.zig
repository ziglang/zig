fn func() bogus {}
fn func() bogus {}
export fn entry() usize { return @sizeOf(@TypeOf(func)); }

// error
// backend=stage1
// target=native
//
// tmp.zig:2:1: error: redeclaration of 'func'
// tmp.zig:1:1: note: other declaration here

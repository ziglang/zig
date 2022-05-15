const x = 3;
const y = &x;
fn foo() *const i32 { return y; }
export fn entry() usize { return @sizeOf(@TypeOf(foo)); }

// error
// backend=stage1
// target=native
//
// tmp.zig:3:30: error: expected type '*const i32', found '*const comptime_int'

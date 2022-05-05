const y = foo(0);
fn foo(x: u32) u32 {
    return 1 / x;
}

export fn entry() usize { return @sizeOf(@TypeOf(y)); }

// error
// backend=stage1
// target=native
//
// tmp.zig:3:14: error: division by zero

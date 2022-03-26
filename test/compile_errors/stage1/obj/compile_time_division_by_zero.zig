const y = foo(0);
fn foo(x: u32) u32 {
    return 1 / x;
}

export fn entry() usize { return @sizeOf(@TypeOf(y)); }

// compile time division by zero
//
// tmp.zig:3:14: error: division by zero

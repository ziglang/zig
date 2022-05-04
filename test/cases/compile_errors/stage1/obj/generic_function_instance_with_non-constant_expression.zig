fn foo(comptime x: i32, y: i32) i32 { return x + y; }
fn test1(a: i32, b: i32) i32 {
    return foo(a, b);
}

export fn entry() usize { return @sizeOf(@TypeOf(test1)); }

// error
// backend=stage1
// target=native
//
// tmp.zig:3:16: error: runtime value cannot be passed to comptime arg

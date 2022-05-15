export fn entry() void {
    const x = @as(usize, -10);
    _ = x;
}

// error
// backend=stage1
// target=native
//
// tmp.zig:2:26: error: cannot cast negative value -10 to unsigned integer type 'usize'

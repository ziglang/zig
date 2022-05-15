export fn a() void {
    _ = @as(f32, 1.0) +| @as(f32, 1.0);
}

// error
// backend=stage1
// target=native
//
// error: invalid operands to binary expression: 'f32' and 'f32'

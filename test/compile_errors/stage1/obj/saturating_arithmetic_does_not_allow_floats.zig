export fn a() void {
    _ = @as(f32, 1.0) +| @as(f32, 1.0);
}

// saturating arithmetic does not allow floats
//
// error: invalid operands to binary expression: 'f32' and 'f32'

export fn entry() void {
    const float: f32 = 5.99999999999994648725e-01;
    const float_ptr = &float;
    const int_ptr = @ptrCast(*const i64, float_ptr);
    const int_val = int_ptr.*;
    _ = int_val;
}

// error
// backend=stage2
// target=native
//
// :5:28: error: dereference of '*const i64' exceeds bounds of containing decl of type 'f32'

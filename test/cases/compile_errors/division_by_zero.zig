const lit_int_x = 1 / 0;
const lit_float_x = 1.0 / 0.0;
const int_x = @as(u32, 1) / @as(u32, 0);
const float_x = @as(f32, 1.0) / @as(f32, 0.0);

export fn entry1() usize {
    return @sizeOf(@TypeOf(lit_int_x));
}
export fn entry2() usize {
    return @sizeOf(@TypeOf(lit_float_x));
}
export fn entry3() usize {
    return @sizeOf(@TypeOf(int_x));
}
export fn entry4() usize {
    return @sizeOf(@TypeOf(float_x));
} // no error on purpose

// error
// backend=stage2
// target=native
//
// :1:23: error: division by zero here causes undefined behavior
// :2:27: error: division by zero here causes undefined behavior
// :3:29: error: division by zero here causes undefined behavior

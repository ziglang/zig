export fn entry1() void {
    var f: f32 = 54.0 / 5;
    _ = f;
}
export fn entry2() void {
    var f: f32 = 54 / 5.0;
    _ = f;
}
export fn entry3() void {
    var f: f32 = 55.0 / 5;
    _ = f;
}
export fn entry4() void {
    var f: f32 = 55 / 5.0;
    _ = f;
}

// error
// backend=stage2
// target=native
//
// :2:23: error: ambiguous coercion of division operands 'comptime_float' and 'comptime_int'; non-zero remainder '4'
// :6:21: error: ambiguous coercion of division operands 'comptime_int' and 'comptime_float'; non-zero remainder '4'

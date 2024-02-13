pub export fn entry() void {
    var a: u32 = 0;
    _ = &a;
    _ = @as(comptime_int, a);
}
pub export fn entry2() void {
    var a: u32 = 0;
    _ = &a;
    _ = @as(comptime_float, a);
}
pub export fn entry3() void {
    comptime var aa: comptime_float = 0.0;
    var a: f32 = 4;
    _ = &a;
    aa = a;
}
pub export fn entry4() void {
    comptime var aa: comptime_int = 0.0;
    var a: f32 = 4;
    _ = &a;
    aa = a;
}

// error
// backend=stage2
// target=native
//
// :4:27: error: unable to resolve comptime value
// :4:27: note: value being casted to 'comptime_int' must be comptime-known
// :9:29: error: unable to resolve comptime value
// :9:29: note: value being casted to 'comptime_float' must be comptime-known
// :15:10: error: unable to resolve comptime value
// :15:10: note: value being casted to 'comptime_float' must be comptime-known
// :21:10: error: unable to resolve comptime value
// :21:10: note: value being casted to 'comptime_int' must be comptime-known

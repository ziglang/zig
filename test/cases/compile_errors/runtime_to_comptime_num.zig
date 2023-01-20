pub export fn entry() void {
    var a: u32 = 0;
    _ = @as(comptime_int, a);
}
pub export fn entry2() void{
    var a: u32 = 0;
    _ = @as(comptime_float, a);
}
pub export fn entry3() void{
    comptime var aa: comptime_float = 0.0;
    var a: f32 = 4;
    aa = a;
}
pub export fn entry4() void{
    comptime var aa: comptime_int = 0.0;
    var a: f32 = 4;
    aa = a;
}

// error
// backend=stage2
// target=native
//
// :3:27: error: unable to resolve comptime value
// :3:27: note: value being casted to 'comptime_int' must be comptime-known
// :7:29: error: unable to resolve comptime value
// :7:29: note: value being casted to 'comptime_float' must be comptime-known
// :12:10: error: unable to resolve comptime value
// :12:10: note: value being casted to 'comptime_float' must be comptime-known
// :17:10: error: unable to resolve comptime value
// :17:10: note: value being casted to 'comptime_int' must be comptime-known

const x = @extern(*comptime_int, .{ .name = "foo" });
const y = @extern(*fn (u8) u8, .{ .name = "bar" });
pub export fn entry() void {
    _ = x;
}
pub export fn entry2() void {
    _ = y;
}

// error
// backend=stage2
// target=native
//
// :1:19: error: extern symbol cannot have type '*comptime_int'
// :1:19: note: pointer to comptime-only type 'comptime_int'
// :2:19: error: extern symbol cannot have type '*fn (u8) u8'
// :2:19: note: pointer to extern function must be 'const'
// :2:19: note: extern function must specify calling convention

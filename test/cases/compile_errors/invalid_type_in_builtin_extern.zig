const x = @extern(*comptime_int, .{ .name = "foo" });
pub export fn entry() void {
    _ = x;
}

// error
// backend=stage2
// target=native
//
// :1:19: error: extern symbol cannot have type '*comptime_int'
// :1:19: note: pointer to comptime-only type 'comptime_int'

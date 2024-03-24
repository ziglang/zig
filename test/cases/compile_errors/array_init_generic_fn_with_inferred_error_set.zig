pub export fn entry() void {
    _ = my_func{u8} catch {};
}
pub export fn entry1() void {
    _ = my_func{} catch {};
}
fn my_func(comptime T: type) !T {}

// error
//
// :2:9: error: expected type 'type', found 'fn (comptime type) @typeInfo(@typeInfo(@TypeOf(tmp.my_func)).Fn.return_type.?).ErrorUnion.error_set!anytype'
// :5:9: error: expected type 'type', found 'fn (comptime type) @typeInfo(@typeInfo(@TypeOf(tmp.my_func)).Fn.return_type.?).ErrorUnion.error_set!anytype'

const foo_tl = @extern(*i32, .{ .name = "foo", .is_thread_local = true });
const foo_dll = @extern(*i32, .{ .name = "foo", .is_dll_import = true });
pub export fn entry() void {
    _ = foo_tl;
}
pub export fn entry2() void {
    _ = foo_dll;
}
// error
//
// :1:16: error: unable to resolve comptime value
// :1:16: note: initializer of container-level variable must be comptime-known
// :2:17: error: unable to resolve comptime value
// :2:17: note: initializer of container-level variable must be comptime-known

pub export fn entry1() void {
    @export(u100, .{ .name = "a" });
}
pub export fn entry3() void {
    @export(undefined, .{ .name = "b" });
}
pub export fn entry4() void {
    @export(null, .{ .name = "c" });
}
pub export fn entry5() void {
    @export(false, .{ .name = "d" });
}
pub export fn entry6() void {
    @export(u8, .{ .name = "e" });
}
pub export fn entry7() void {
    @export(u65535, .{ .name = "f" });
}

// error
// backend=llvm
// target=native
//
// :2:13: error: unable to export primitive value
// :5:13: error: unable to export primitive value
// :8:13: error: unable to export primitive value
// :11:13: error: unable to export primitive value
// :14:13: error: unable to export primitive value
// :17:13: error: unable to export primitive value

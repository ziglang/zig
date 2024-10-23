var self = "aoeu";
fn f(m: []const u8) void {
    m.copy(u8, self[0..], m);
}
export fn entry() usize {
    return @sizeOf(@TypeOf(&f));
}
pub export fn entry1() void {
    .{}.bar();
}
pub export fn entry2() void {
    .{ .foo = 1 }.bar();
}

// error
// backend=stage2
// target=native
//
// :3:6: error: no field or member function named 'copy' in '[]const u8'
// :9:8: error: no field or member function named 'bar' in '@TypeOf(.{})'
// :12:18: error: no field or member function named 'bar' in 'struct{comptime foo: comptime_int = 1}'

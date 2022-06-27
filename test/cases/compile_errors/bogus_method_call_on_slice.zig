var self = "aoeu";
fn f(m: []const u8) void {
    m.copy(u8, self[0..], m);
}
export fn entry() usize { return @sizeOf(@TypeOf(&f)); }

// error
// backend=stage2
// target=native
//
// :3:6: error: type '[]const u8' has no field or member function named 'copy'

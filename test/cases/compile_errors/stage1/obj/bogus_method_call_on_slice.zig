var self = "aoeu";
fn f(m: []const u8) void {
    m.copy(u8, self[0..], m);
}
export fn entry() usize { return @sizeOf(@TypeOf(f)); }

// error
// backend=stage1
// target=native
//
// tmp.zig:3:6: error: no member named 'copy' in '[]const u8'

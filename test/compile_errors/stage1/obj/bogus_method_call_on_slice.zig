var self = "aoeu";
fn f(m: []const u8) void {
    m.copy(u8, self[0..], m);
}
export fn entry() usize { return @sizeOf(@TypeOf(f)); }

// bogus method call on slice
//
// tmp.zig:3:6: error: no member named 'copy' in '[]const u8'

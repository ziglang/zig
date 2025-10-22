pub fn reassign(s: []const u8) void {
    s = s[0..];
}
export fn entry() void {
    reassign("foo");
}

// error
//
// :2:5: error: cannot assign to constant

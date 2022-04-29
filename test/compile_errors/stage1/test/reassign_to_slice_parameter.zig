pub fn reassign(s: []const u8) void {
    s = s[0..];
}
export fn entry() void {
    reassign("foo");
}

// error
// backend=stage1
// target=native
// is_test=1
//
// tmp.zig:2:10: error: cannot assign to constant

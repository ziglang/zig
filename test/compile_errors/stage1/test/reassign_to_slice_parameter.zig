pub fn reassign(s: []const u8) void {
    s = s[0..];
}
export fn entry() void {
    reassign("foo");
}

// reassign to slice parameter
//
// tmp.zig:2:10: error: cannot assign to constant

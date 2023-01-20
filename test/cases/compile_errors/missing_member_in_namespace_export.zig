const S = struct {};
comptime {
    @export(S.foo, .{ .name = "foo" });
}

// error
// target=native
//
// :3:14: error: struct 'tmp.S' has no member named 'foo'
// :1:11: note: struct declared here

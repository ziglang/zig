const S = struct {};
comptime {
    @export(S.foo, .{ .name = "foo" });
}

// error
// target=native
//
// :3:14: error: struct 'struct {}' has no member named 'foo'

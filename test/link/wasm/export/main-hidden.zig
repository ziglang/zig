fn foo() callconv(.c) void {}
comptime {
    @export(&foo, .{ .name = "foo", .visibility = .hidden });
}

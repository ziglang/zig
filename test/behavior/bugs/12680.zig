// export this function twice
pub export fn testFunc() callconv(.C) void {}

comptime {
    @export(testFunc, .{ .name = "test_func", .linkage = .Strong });
}

test "export a function twice" {
    _ = testFunc();
}

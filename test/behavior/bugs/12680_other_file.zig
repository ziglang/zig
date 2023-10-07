// export this function twice
pub export fn testFunc() callconv(.C) usize {
    return @intFromPtr(&testFunc);
}

comptime {
    @export(testFunc, .{ .name = "test_func", .linkage = .Strong });
}

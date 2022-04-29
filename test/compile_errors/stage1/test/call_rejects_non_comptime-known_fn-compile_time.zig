pub export fn entry() void {
    var call_me: fn () void = undefined;
    @call(.{ .modifier = .compile_time }, call_me, .{});
}

// error
// backend=stage1
// target=native
// is_test=1
//
// tmp.zig:3:5: error: the specified modifier requires a comptime-known function

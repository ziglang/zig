pub export fn entry() void {
    var call_me: fn () void = undefined;
    @call(.{ .modifier = .compile_time }, call_me, .{});
}

// @call rejects non comptime-known fn - compile_time
//
// tmp.zig:3:5: error: the specified modifier requires a comptime-known function

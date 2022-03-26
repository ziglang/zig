pub export fn entry() void {
    var call_me: fn () void = undefined;
    @call(.{ .modifier = .always_inline }, call_me, .{});
}

// @call rejects non comptime-known fn - always_inline
//
// tmp.zig:3:5: error: the specified modifier requires a comptime-known function

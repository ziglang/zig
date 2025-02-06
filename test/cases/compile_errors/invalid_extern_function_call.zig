const x = @extern(*const fn () callconv(.c) void, .{ .name = "foo" });

export fn entry0() void {
    comptime x();
}

export fn entry1() void {
    @call(.always_inline, x, .{});
}

// error
//
// :4:15: error: comptime call of extern function
// :4:5: note: 'comptime' keyword forces comptime evaluation
// :8:5: error: inline call of extern function

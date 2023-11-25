fn a() void {}

export fn b() void {
    @call(.always_inline, &a, .{});
}

// error
//
// :5:5: error: inline call of function pointer
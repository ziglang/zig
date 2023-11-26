fn a() void {}

export fn b() void {
    @call(.always_inline, &a, .{});
}

// error
//
// :4:5: error: inline call of function pointer

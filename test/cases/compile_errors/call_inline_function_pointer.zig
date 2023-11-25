inline fn a() void {}

export fn b() void {
    @call(.auto, &a, .{});
}

// error
//
// :4:5: error: calling pointer of inline function

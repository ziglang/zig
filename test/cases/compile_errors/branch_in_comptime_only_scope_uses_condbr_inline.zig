pub export fn entry1() void {
    var x: u32 = 3;
    _ = @shuffle(u32, [_]u32{0}, @splat(1, @as(u32, 0)), [_]i8{
        if (x > 1) 1 else -1,
    });
}

pub export fn entry2() void {
    var y: ?i8 = -1;
    _ = @shuffle(u32, [_]u32{0}, @splat(1, @as(u32, 0)), [_]i8{
        y orelse 1,
    });
}

// error
// backend=stage2
// target=native
//
// :4:15: error: unable to evaluate comptime expression
// :4:13: note: operation is runtime due to this operand
// :11:11: error: unable to evaluate comptime expression

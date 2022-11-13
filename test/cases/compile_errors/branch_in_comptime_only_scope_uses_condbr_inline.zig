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
// :4:15: error: unable to resolve comptime value
// :4:15: note: condition in comptime branch must be comptime-known
// :11:11: error: unable to resolve comptime value
// :11:11: note: condition in comptime branch must be comptime-known

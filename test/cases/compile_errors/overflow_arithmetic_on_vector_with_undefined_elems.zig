comptime {
    const a: @Vector(3, u8) = .{ 1, 200, undefined };
    @compileLog(@addWithOverflow(a, a));
}

comptime {
    const a: @Vector(3, u8) = .{ 1, 2, undefined };
    const b: @Vector(3, u8) = .{ 0, 3, 10 };
    @compileLog(@subWithOverflow(a, b));
}

comptime {
    const a: @Vector(3, u8) = .{ 1, 200, undefined };
    @compileLog(@mulWithOverflow(a, a));
}

// error
//
// :3:5: error: found compile log statement
// :9:5: note: also here
// :14:5: note: also here
//
// Compile Log Output:
// @as(struct{@Vector(3, u8), @Vector(3, u1)}, .{ .{ 2, 144, undefined }, .{ 0, 1, undefined } })
// @as(struct{@Vector(3, u8), @Vector(3, u1)}, .{ .{ 1, 255, undefined }, .{ 0, 1, undefined } })
// @as(struct{@Vector(3, u8), @Vector(3, u1)}, .{ .{ 1, 64, undefined }, .{ 0, 1, undefined } })

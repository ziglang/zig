export fn entry1() void {
    const x: i32 = undefined;
    const y: u32 = @bitCast(x);
    @compileLog(y);
}

export fn entry2() void {
    const x: packed struct { x: u16, y: u16 } = .{ .x = 123, .y = undefined };
    const y: u32 = @bitCast(x);
    @compileLog(y);
}

// error
//
// :4:5: error: found compile log statement
// :10:5: note: also here
//
// Compile Log Output:
// @as(u32, undefined)
// @as(u32, undefined)

export fn entry1() void {
    const x: i32 = undefined;
    const y: u32 = @bitCast(x);
    @compileLog(y);
}

// error
//
// :4:5: error: found compile log statement
//
// Compile Log Output:
// @as(u32, undefined)

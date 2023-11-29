export fn _start() noreturn {
    const b = true;
    var f: u32 = 1;
    _ = &f;
    @compileLog(b, 20, f, x);
    @compileLog(1000);
    unreachable;
}
export fn other() void {
    @compileLog(1234);
}
fn x() void {}

// error
//
// :9:5: error: found compile log statement
// :4:5: note: also here
//
// Compile Log Output:
// @as(bool, true), @as(comptime_int, 20), @as(u32, [runtime value]), @as(fn () void, (function 'x'))
// @as(comptime_int, 1000)

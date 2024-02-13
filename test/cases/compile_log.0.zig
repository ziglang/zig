export fn _start() noreturn {
    const b = true;
    var f: u32 = 1;
    @compileLog(b, 20, f, x);
    @compileLog(1000);
    var bruh: usize = true;
    _ = .{ &f, &bruh };
    unreachable;
}
export fn other() void {
    @compileLog(1234);
}
fn x() void {}

// error
//
// :6:23: error: expected type 'usize', found 'bool'
//
// Compile Log Output:
// @as(bool, true), @as(comptime_int, 20), @as(u32, [runtime value]), @as(fn () void, (function 'x'))
// @as(comptime_int, 1000)
// @as(comptime_int, 1234)

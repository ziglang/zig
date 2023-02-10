export fn _start() noreturn {
    const b = true;
    var f: u32 = 1;
    @compileLog(b, 20, f, x);
    @compileLog(1000);
    var bruh: usize = true;
    _ = bruh;
    unreachable;
}
export fn other() void {
    @compileLog(1234);
}
fn x() void {}

// error
//
// :6:23: error: expected type 'usize', found 'bool'

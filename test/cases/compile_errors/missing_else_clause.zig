fn f(b: bool) void {
    const x : i32 = if (b) h: { break :h 1; };
    _ = x;
}
fn g(b: bool) void {
    const y = if (b) h: { break :h @as(i32, 1); };
    _ = y;
}
export fn entry() void { f(true); g(true); }

// error
// backend=stage2
// target=native
//
// :2:21: error: incompatible types: 'i32' and 'void'
// :6:15: error: incompatible types: 'i32' and 'void'

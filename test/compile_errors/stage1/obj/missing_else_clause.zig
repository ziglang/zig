fn f(b: bool) void {
    const x : i32 = if (b) h: { break :h 1; };
    _ = x;
}
fn g(b: bool) void {
    const y = if (b) h: { break :h @as(i32, 1); };
    _ = y;
}
export fn entry() void { f(true); g(true); }

// missing else clause
//
// tmp.zig:2:21: error: expected type 'i32', found 'void'
// tmp.zig:6:15: error: incompatible types: 'i32' and 'void'

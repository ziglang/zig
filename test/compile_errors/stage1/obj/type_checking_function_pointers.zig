fn a(b: fn (*const u8) void) void {
    b('a');
}
fn c(d: u8) void {_ = d;}
export fn entry() void {
    a(c);
}

// error
// backend=stage1
// target=native
//
// tmp.zig:6:7: error: expected type 'fn(*const u8) void', found 'fn(u8) void'

fn a(b: *const fn (*const u8) void) void {
    _ = b;
}
fn c(d: u8) void {_ = d;}
export fn entry() void {
    a(c);
}

// error
// backend=stage2
// target=native
//
// :6:6: error: expected type '*const fn(*const u8) void', found '*const fn(u8) void'
// :6:6: note: pointer type child 'fn(u8) void' cannot cast into pointer type child 'fn(*const u8) void'
// :6:6: note: parameter 0 'u8' cannot cast into '*const u8'

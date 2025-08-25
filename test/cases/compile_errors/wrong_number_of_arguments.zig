export fn a() void {
    c(1);
}
fn c(d: i32, e: i32, f: i32) void {
    _ = d;
    _ = e;
    _ = f;
}

// error
// backend=stage2
// target=native
//
// :2:5: error: expected 3 argument(s), found 1
// :4:1: note: function declared here

pub fn main() void {
    var i: u8 = 5;
    var y: f32 = 42.0;
    _ = &y;
    var x: u8 = 10;
    _ = &x;
    foo(i, x);
    i = x;
    if (i != 10) unreachable;
}
fn foo(x: u8, y: u8) void {
    _ = y;
    var i: u8 = 10;
    i = x;
}

// run
//

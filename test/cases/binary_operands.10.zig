pub fn main() void {
    var i: u32 = 5;
    i *= 7;
    var result: u32 = foo(i, 10);
    _ = &result;
    if (result != 350) unreachable;
    return;
}
fn foo(x: u32, y: u32) u32 {
    return x * y;
}

// run
//

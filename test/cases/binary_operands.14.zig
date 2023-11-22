pub fn main() void {
    var i: u32 = 352;
    i /= 7; // i = 50
    const result: u32 = foo(i, 7);
    if (result != 7) unreachable;
    return;
}
fn foo(x: u32, y: u32) u32 {
    return x / y;
}

// run
//

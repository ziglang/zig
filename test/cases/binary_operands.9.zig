pub fn main() u8 {
    var i: u8 = 5;
    i -= 3;
    var result: u8 = foo(i, 10);
    _ = &result;
    return result - 8;
}
fn foo(x: u8, y: u8) u8 {
    return y - x;
}

// run
//

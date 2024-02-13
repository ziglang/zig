pub fn main() u8 {
    var i: u8 = 5;
    i += 20;
    const result: u8 = foo(i, 10);
    return result - 35;
}
fn foo(x: u8, y: u8) u8 {
    return x + y;
}

// run
//

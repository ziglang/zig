pub fn main() u8 {
    var x: ?u8 = null;
    _ = &x;
    var y: u8 = 0;
    if (x) |val| {
        y = val;
    }
    return y;
}

// run
//

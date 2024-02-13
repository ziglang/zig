pub fn main() u8 {
    var x: ?u8 = 5;
    _ = &x;
    return x.? - 5;
}

// run
//

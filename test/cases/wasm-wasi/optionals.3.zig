pub fn main() u8 {
    var x: u8 = 5;
    var y: ?u8 = x;
    return y.? - 5;
}

// run
//

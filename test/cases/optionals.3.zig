pub fn main() u8 {
    var x: u8 = 5;
    var y: ?u8 = x;
    _ = .{ &x, &y };
    return y.? - 5;
}

// run
//

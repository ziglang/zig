pub fn main() u8 {
    var i: u8 = 5;
    if (i < @as(u8, 4)) {
        i += 10;
    } else {
        i = 2;
    }
    return i - 2;
}

// run
//

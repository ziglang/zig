pub fn main() u8 {
    var i: u8 = 5;
    if (i < @as(u8, 4)) {
        i += 10;
    } else if (i == @as(u8, 5)) {
        i = 20;
    }
    return i - 20;
}

// run
//

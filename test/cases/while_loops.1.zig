pub fn main() u8 {
    var i: u8 = 0;
    while (i < @as(u8, 10)) {
        var x: u8 = 1;
        i += x;
    }
    return i - 10;
}

// run
//

pub fn main() u8 {
    var i: u8 = 0;
    while (i < @as(u8, 10)) {
        var x: u8 = 1;
        _ = &x;
        i += x;
        if (i == @as(u8, 5)) break;
    }
    return i - 5;
}

// run
//

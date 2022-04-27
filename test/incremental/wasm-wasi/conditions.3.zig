pub fn main() u8 {
    var i: u8 = 11;
    if (i < @as(u8, 4)) {
        i += 10;
    } else {
        if (i > @as(u8, 10)) {
            i += 20;
        } else {
            i = 20;
        }
    }
    return i - 31;
}

// run
//

pub fn main() u8 {
    var e: anyerror!u8 = 5;
    const i = e catch 10;
    return i - 5;
}

// run
//

pub fn main() u8 {
    var e: anyerror!u8 = 5;
    _ = &e;
    const i = e catch 10;
    return i - 5;
}

// run
//

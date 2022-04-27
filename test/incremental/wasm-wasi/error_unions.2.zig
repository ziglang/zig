pub fn main() u8 {
    var e: anyerror!u8 = error.Foo;
    const i = e catch 10;
    return i - 10;
}

// run
//

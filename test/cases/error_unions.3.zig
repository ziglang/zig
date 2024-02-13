pub fn main() u8 {
    var e = foo();
    _ = &e;
    const i = e catch 69;
    return i - 5;
}

fn foo() anyerror!u8 {
    return 5;
}

// run
//

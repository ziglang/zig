pub fn main() u8 {
    var e = foo();
    _ = &e;
    const i = e catch 42;
    return i - 42;
}

fn foo() anyerror!u8 {
    return error.Dab;
}

// run
//

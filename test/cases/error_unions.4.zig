pub fn main() u8 {
    var e = foo();
    const i = e catch 69;
    return i - 69;
}

fn foo() anyerror!u8 {
    return error.Bruh;
}

// run
//

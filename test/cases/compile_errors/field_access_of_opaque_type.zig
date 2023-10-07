const MyType = opaque {};

export fn entry() bool {
    var x: i32 = 1;
    return bar(@ptrCast(&x));
}

fn bar(x: *MyType) bool {
    return x.blah;
}

// error
// backend=stage2
// target=native
//
// :9:13: error: type '*tmp.MyType' does not support field access

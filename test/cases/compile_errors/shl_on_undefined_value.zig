comptime {
    var a: i64 = undefined;
    var b: u6 = undefined;
    _ = &a;
    _ = &b;
    _ = a << b;
}

// error
//
// :6:9: error: use of undefined value here causes illegal behavior

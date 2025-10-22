comptime {
    var a: i64 = undefined;
    var b: u6 = undefined;
    _ = &a;
    _ = &b;
    _ = @shrExact(a, b);
}

// error
//
// :6:19: error: use of undefined value here causes illegal behavior

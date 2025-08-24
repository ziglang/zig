comptime {
    var a: i64 = undefined;
    var b: u6 = undefined;
    _ = &a;
    _ = &b;
    _ = @shlWithOverflow(a, b);
}

// error
//
// :6:26: error: use of undefined value here causes illegal behavior

comptime {
    var a: i64 = undefined;
    _ = a / a;
    _ = &a;
}

// error
// backend=stage2
// target=native
//
// :3:13: error: use of undefined value here causes undefined behavior

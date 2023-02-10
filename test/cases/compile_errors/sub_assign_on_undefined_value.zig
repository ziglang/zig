comptime {
    var a: i64 = undefined;
    a -= a;
}

// error
// backend=stage2
// target=native
//
// :3:10: error: use of undefined value here causes undefined behavior

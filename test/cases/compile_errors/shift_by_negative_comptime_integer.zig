comptime {
    var a = 1 >> -1;
    _ = a;
}

// error
// backend=stage2
// target=native
//
// :2:18: error: shift by negative amount '-1'

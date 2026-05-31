comptime {
    const a = 1 >> -1;
    _ = a;
}

// error
//
// :2:20: error: shift by negative amount '-1'

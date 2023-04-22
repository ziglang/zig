comptime {
    _ = [1]anyopaque;
}
comptime {
    _ = [1]noreturn;
}

// error
// backend=stage2
// target=native
//
// :2:12: error: array of opaque type 'anyopaque' not allowed
// :5:12: error: array of 'noreturn' not allowed

comptime {
    _ = [1]anyopaque;
}
comptime {
    _ = [1]noreturn;
}

// error
//
// :2:12: error: array of opaque type 'anyopaque' not allowed
// :5:12: error: array of 'noreturn' not allowed

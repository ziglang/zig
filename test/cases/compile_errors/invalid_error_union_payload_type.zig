comptime {
    _ = anyerror!anyopaque;
}
comptime {
    _ = anyerror!anyerror;
}

// error
// backend=stage2
// target=native
//
// :2:18: error: error union with payload of opaque type 'anyopaque' not allowed
// :5:18: error: error union with payload of error set type 'anyerror' not allowed

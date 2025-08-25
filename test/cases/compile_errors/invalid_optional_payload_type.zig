comptime {
    _ = ?anyopaque;
}
comptime {
    _ = ?@TypeOf(null);
}

// error
// backend=stage2
// target=native
//
// :2:10: error: opaque type 'anyopaque' cannot be optional
// :5:10: error: type '@TypeOf(null)' cannot be optional

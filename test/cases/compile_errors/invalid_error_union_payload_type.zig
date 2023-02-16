comptime {
    _ = anyerror!anyopaque;
}
comptime {
    _ = anyerror!anyerror;
}
fn someFunction() !anyerror {
    return error.C;
}
comptime {
    _ = someFunction;
}

// error
// backend=stage2
// target=native
//
// :2:18: error: error union with payload of opaque type 'anyopaque' not allowed
// :5:18: error: error union with payload of error set type 'anyerror' not allowed
// :7:20: error: error union with payload of error set type 'anyerror' not allowed

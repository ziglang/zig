fn inner() !void {
    return error.SomethingBadHappened;
}

fn outer() !void {
    return inner();
}

comptime {
    outer() catch unreachable;
}

// error
//
// :10:19: error: caught unexpected error 'SomethingBadHappened'
// :2:18: note: error returned here
// :6:5: note: error returned here

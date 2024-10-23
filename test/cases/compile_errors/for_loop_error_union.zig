fn b() !u32 {
    return 2;
}

export fn a() void {
    for (b()) |_| {}
}

// error
// backend=stage2
// target=native
//
// :6:11: error: type '@typeInfo(@typeInfo(@TypeOf(tmp.b)).@"fn".return_type.?).error_union.error_set!u32' is not indexable and not a range
// :6:11: note: for loop operand must be a range, array, slice, tuple, or vector
// :6:11: note: consider using 'try', 'catch', or 'if'

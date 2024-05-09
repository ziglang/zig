fn align1() align(1) void {}
fn align2() align(2) void {}

comptime {
    _ = @as(*align(1) const fn () void, &align2);
    _ = @as(*align(1) const fn () void, &align1);
    _ = @as(*align(2) const fn () void, &align2);
    _ = @as(*align(2) const fn () void, &align1);
}

// error
// backend=stage2
// target=native
//
// :8:41: error: expected type '*align(2) const fn () void', found '*const fn () void'
// :8:41: note: pointer alignment '1' cannot cast into pointer alignment '2'

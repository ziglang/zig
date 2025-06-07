comptime {
    _ = @min(0, false);
}

// error
// backend=stage2
// target=native
//
// :2:17: error: expected number, found 'bool'

comptime { _ = @min(1); }
comptime { _ = @max(1); }

// error
// backend=stage2
// target=native
//
// :1:16: error: expected at least 2 arguments, found 1
// :2:16: error: expected at least 2 arguments, found 1

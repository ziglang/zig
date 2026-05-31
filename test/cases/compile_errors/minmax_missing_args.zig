comptime { _ = @min(1); }
comptime { _ = @max(1); }

// error
//
// :1:16: error: expected at least 2 arguments, found 1
// :2:16: error: expected at least 2 arguments, found 1

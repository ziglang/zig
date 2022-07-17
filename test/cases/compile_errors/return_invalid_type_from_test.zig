test "example" { return 1; }

// error
// backend=stage2
// target=native
// is_test=1
//
// :1:25: error: expected type 'void', found 'comptime_int'

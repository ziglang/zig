test "example" { return 1; }

// error
// backend=stage1
// target=native
// is_test=1
//
// tmp.zig:1:25: error: expected type 'void', found 'comptime_int'

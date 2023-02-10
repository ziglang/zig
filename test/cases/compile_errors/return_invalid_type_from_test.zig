test "example" { return 1; }

// error
// backend=stage2
// target=native
// is_test=1
//
// :1:25: error: expected type '@typeInfo(@typeInfo(@TypeOf(tmp.test.example)).Fn.return_type.?).ErrorUnion.error_set!void', found 'comptime_int'
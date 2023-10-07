test "example" {
    return 1;
}

// error
// backend=stage2
// target=native
// is_test=1
//
// :2:12: error: expected type 'anyerror!void', found 'comptime_int'

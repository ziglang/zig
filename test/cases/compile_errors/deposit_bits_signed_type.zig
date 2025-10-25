export fn entry() void {
    var a: i32 = 0;
    var b: i32 = 0;
    var res = @depositBits(a, b);
    _ = &a;
    _ = &b;
    _ = &res;
}

// error
// is_test=true
//
// :4:28: error: expected unsigned integer or 'comptime_int', found 'i32'

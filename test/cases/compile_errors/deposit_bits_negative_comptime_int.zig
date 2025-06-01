export fn entry() void {
    const a = 0;
    const b = -1;
    const res = @depositBits(a, b);
    _ = res;
}

// error
// is_test=true
//
// :4:33: error: use of negative value '-1'
// :4:17: note: parameters to @depositBits must be non-negative

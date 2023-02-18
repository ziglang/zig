export fn a() void {
    for (0..10, 10..21) |i, j| {
        _ = i; _ = j;
    }
}
export fn b() void {
    const s1 = "hello";
    const s2 = true;
    for (s1, s2) |i, j| {
        _ = i; _ = j;
    }
}
export fn c() void {
    var buf: [10]u8 = undefined;
    for (buf) |*byte| {
        _ = byte;
    }
}

// error
// backend=stage2
// target=native
//
// :2:5: error: non-matching for loop lengths
// :2:11: note: length 10 here
// :2:19: note: length 11 here
// :9:14: error: type 'bool' does not support indexing
// :9:14: note: for loop operand must be an array, slice, tuple, or vector
// :15:16: error: pointer capture of non pointer type '[10]u8'
// :15:10: note: consider using '&' here

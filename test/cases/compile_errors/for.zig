export fn a() void {
    for (0..10, 10..21) |i, j| {
        _ = i;
        _ = j;
    }
}
export fn b() void {
    const s1 = "hello";
    const s2 = true;
    for (s1, s2) |i, j| {
        _ = i;
        _ = j;
    }
}
export fn c() void {
    var buf: [10]u8 = undefined;
    for (buf) |*byte| {
        _ = byte;
    }
    _ = &buf;
}
export fn d() void {
    const x: [*]const u8 = "hello";
    const y: [*]const u8 = "world";
    for (x, 0.., y) |x1, x2, x3| {
        _ = x1;
        _ = x2;
        _ = x3;
    }
}

// error
// backend=stage2
// target=native
//
// :2:5: error: non-matching for loop lengths
// :2:11: note: length 10 here
// :2:19: note: length 11 here
// :10:14: error: type 'bool' is not indexable and not a range
// :10:14: note: for loop operand must be a range, array, slice, tuple, or vector
// :17:16: error: pointer capture of non pointer type '[10]u8'
// :17:10: note: consider using '&' here
// :25:5: error: unbounded for loop
// :25:10: note: type '[*]const u8' has no upper bound
// :25:18: note: type '[*]const u8' has no upper bound

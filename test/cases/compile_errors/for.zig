export fn a() void {
    for (0..10, 10..21) |i, j| {
        _ = i; _ = j;
    }
}

// error
// backend=stage2
// target=native
//
// :2:5: error: non-matching for loop lengths
// :2:11: note: length 10 here
// :2:19: note: length 11 here

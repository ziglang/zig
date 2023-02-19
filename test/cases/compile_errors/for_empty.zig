export fn b() void {
    for () |i| {
        _ = i;
    }
}

// error
// backend=stage2
// target=native
//
// :2:10: error: expected expression, found ')'

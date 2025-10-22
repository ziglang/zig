export fn b() void {
    for () |i| {
        _ = i;
    }
}

// error
//
// :2:10: error: expected expression, found ')'

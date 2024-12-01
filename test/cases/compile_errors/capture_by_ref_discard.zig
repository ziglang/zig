export fn a() void {
    for (.{}) |*_| {}
}

export fn b() void {
    switch (0) {
        else => |*_| {},
    }
}

export fn c() void {
    if (null) |*_| {}
}

export fn d() void {
    while (null) |*_| {}
}

// error
// backend=stage2
// target=native
//
// :2:16: error: pointer modifier invalid on discard
// :7:18: error: pointer modifier invalid on discard
// :12:16: error: pointer modifier invalid on discard
// :16:19: error: pointer modifier invalid on discard

export fn bigger(a: *const [10]u32) void {
    const b: *const [20]u32 = a;
    _ = b;
}

comptime {
    const a: *const [10]u32 = &@splat(0);
    const b: *const [20]u32 = a;
    _ = b;
}

export fn biggerSentinel(a: *const [10:0]u32) void {
    const b: *const [20]u32 = a;
    _ = b;
}

comptime {
    const a: *const [10:0]u32 = &@splat(0);
    const b: *const [20]u32 = a;
    _ = b;
}

export fn smaller(a: *const [10]u32) void {
    const b: *const [5]u32 = a;
    _ = b;
}

comptime {
    const a: *const [10]u32 = &@splat(0);
    const b: *const [5]u32 = a;
    _ = b;
}

export fn smallerSentinel(a: *const [10:0]u32) void {
    const b: *const [5]u32 = a;
    _ = b;
}

comptime {
    const a: *const [10:0]u32 = &@splat(0);
    const b: *const [5]u32 = a;
    _ = b;
}

// error
//
// :2:31: error: expected type '*const [20]u32', found '*const [10]u32'
// :2:31: note: pointer type child '[10]u32' cannot cast into pointer type child '[20]u32'
// :2:31: note: array of length 10 cannot cast into an array of length 20
// :8:31: error: expected type '*const [20]u32', found '*const [10]u32'
// :8:31: note: pointer type child '[10]u32' cannot cast into pointer type child '[20]u32'
// :8:31: note: array of length 10 cannot cast into an array of length 20
// :13:31: error: expected type '*const [20]u32', found '*const [10:0]u32'
// :13:31: note: pointer type child '[10:0]u32' cannot cast into pointer type child '[20]u32'
// :13:31: note: array of length 10 cannot cast into an array of length 20
// :19:31: error: expected type '*const [20]u32', found '*const [10:0]u32'
// :19:31: note: pointer type child '[10:0]u32' cannot cast into pointer type child '[20]u32'
// :19:31: note: array of length 10 cannot cast into an array of length 20
// :24:30: error: expected type '*const [5]u32', found '*const [10]u32'
// :24:30: note: pointer type child '[10]u32' cannot cast into pointer type child '[5]u32'
// :24:30: note: array of length 10 cannot cast into an array of length 5
// :30:30: error: expected type '*const [5]u32', found '*const [10]u32'
// :30:30: note: pointer type child '[10]u32' cannot cast into pointer type child '[5]u32'
// :30:30: note: array of length 10 cannot cast into an array of length 5
// :35:30: error: expected type '*const [5]u32', found '*const [10:0]u32'
// :35:30: note: pointer type child '[10:0]u32' cannot cast into pointer type child '[5]u32'
// :35:30: note: array of length 10 cannot cast into an array of length 5
// :41:30: error: expected type '*const [5]u32', found '*const [10:0]u32'
// :41:30: note: pointer type child '[10:0]u32' cannot cast into pointer type child '[5]u32'
// :41:30: note: array of length 10 cannot cast into an array of length 5

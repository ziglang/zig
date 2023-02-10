export fn entry() void {
    const slice = @as([*]i32, undefined)[0..1];
    _ = slice;
}

// error
// backend=stage2
// target=native
//
// :2:41: error: non-zero length slice of undefined pointer

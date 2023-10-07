export fn entry1() void {
    const slice = @as([*]i32, undefined)[0];
    _ = slice;
}

// error
// backend=stage2
// target=native
//
// :2:41: error: use of undefined value here causes undefined behavior

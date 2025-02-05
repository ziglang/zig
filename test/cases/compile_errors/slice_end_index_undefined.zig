export fn a() void {
    var array: [0]void = undefined;
    _ = array[0..undefined];
}

// error
// backend=stage2
// target=native
//
// :3:18: error: use of undefined value here causes undefined behavior

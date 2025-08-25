export fn a() void {
    var array: [0]void = undefined;
    _ = array[0..undefined];
}

// error
//
// :3:18: error: use of undefined value here causes illegal behavior

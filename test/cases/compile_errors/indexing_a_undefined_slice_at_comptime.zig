comptime {
    var slice: []u8 = undefined;
    slice[0] = 2;
}

// error
// backend=stage2
// target=native
//
// :3:10: error: use of undefined value here causes undefined behavior

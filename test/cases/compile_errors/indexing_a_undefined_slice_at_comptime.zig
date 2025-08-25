comptime {
    var slice: []u8 = undefined;
    slice[0] = 2;
}

// error
//
// :3:10: error: use of undefined value here causes illegal behavior

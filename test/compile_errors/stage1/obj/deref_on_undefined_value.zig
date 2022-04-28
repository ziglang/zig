comptime {
    var a: *u8 = undefined;
    _ = a.*;
}

// error
// backend=stage1
// target=native
//
// tmp.zig:3:9: error: attempt to dereference undefined value

comptime {
    const a: *u8 = undefined;
    _ = a.*;
}

// error
// backend=stage2
// target=native
//
// :3:10: error: cannot dereference undefined value

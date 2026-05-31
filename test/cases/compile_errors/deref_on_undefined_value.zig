comptime {
    const a: *u8 = undefined;
    _ = a.*;
}

// error
//
// :3:10: error: cannot dereference undefined value

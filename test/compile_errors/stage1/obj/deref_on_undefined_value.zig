comptime {
    var a: *u8 = undefined;
    _ = a.*;
}

// deref on undefined value
//
// tmp.zig:3:9: error: attempt to dereference undefined value

comptime {
    var a: ?bool = undefined;
    _ = a orelse false;
}

// orelse on undefined value
//
// tmp.zig:3:11: error: use of undefined value here causes undefined behavior

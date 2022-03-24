comptime {
    var a: i64 = undefined;
    _ = -a;
}

// negate on undefined value
//
// tmp.zig:3:10: error: use of undefined value here causes undefined behavior

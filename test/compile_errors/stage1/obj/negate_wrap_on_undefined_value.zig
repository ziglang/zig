comptime {
    var a: i64 = undefined;
    _ = -%a;
}

// negate wrap on undefined value
//
// tmp.zig:3:11: error: use of undefined value here causes undefined behavior

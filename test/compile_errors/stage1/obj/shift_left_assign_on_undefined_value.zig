comptime {
    var a: i64 = undefined;
    a >>= 2;
}

// shift left assign on undefined value
//
// tmp.zig:3:5: error: use of undefined value here causes undefined behavior

comptime {
    var a: bool = undefined;
    _ = !a;
}

// bool not on undefined value
//
// tmp.zig:3:10: error: use of undefined value here causes undefined behavior

comptime {
    var a: bool = undefined;
    _ = a or a;
}

// or on undefined value
//
// tmp.zig:3:9: error: use of undefined value here causes undefined behavior

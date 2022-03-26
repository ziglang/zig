comptime {
    var a: i64 = undefined;
    _ = a *% a;
}

// mult wrap on undefined value
//
// tmp.zig:3:9: error: use of undefined value here causes undefined behavior

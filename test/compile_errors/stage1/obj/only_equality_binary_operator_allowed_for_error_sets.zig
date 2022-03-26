comptime {
    const z = error.A > error.B;
    _ = z;
}

// only equality binary operator allowed for error sets
//
// tmp.zig:2:23: error: operator not allowed for errors

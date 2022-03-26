comptime {
    var a = 1 >> -1;
    _ = a;
}

// shift by negative comptime integer
//
// tmp.zig:2:18: error: shift by negative value -1

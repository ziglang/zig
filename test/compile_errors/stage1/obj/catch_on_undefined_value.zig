comptime {
    var a: anyerror!bool = undefined;
    _ = a catch false;
}

// catch on undefined value
//
// tmp.zig:3:11: error: use of undefined value here causes undefined behavior

comptime {
    var a: anyerror!bool = undefined;
    _ = a catch false;
}

// error
// backend=stage2
// target=native
//
// :3:11: error: use of undefined value here causes undefined behavior

comptime {
    var a: bool = undefined;
    _ = a and a;
}

// error
// backend=stage2
// target=native
//
// :3:9: error: use of undefined value here causes undefined behavior

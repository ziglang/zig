comptime {
    var a: i64 = undefined;
    _ = a % a;
    _ = &a;
}

// error
//
// :3:9: error: use of undefined value here causes illegal behavior

comptime {
    var a: i64 = undefined;
    a += a;
}

// error
//
// :3:5: error: use of undefined value here causes illegal behavior

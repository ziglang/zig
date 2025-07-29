comptime {
    const a: i64 = undefined;
    _ = -a;
}

// error
//
// :3:10: error: use of undefined value here causes illegal behavior

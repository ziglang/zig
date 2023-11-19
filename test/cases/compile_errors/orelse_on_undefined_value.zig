comptime {
    const a: ?bool = undefined;
    _ = a orelse false;
}

// error
// backend=stage2
// target=native
//
// :3:11: error: use of undefined value here causes undefined behavior

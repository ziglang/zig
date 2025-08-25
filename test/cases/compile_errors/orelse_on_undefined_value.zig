comptime {
    const a: ?bool = undefined;
    _ = a orelse false;
}

// error
//
// :3:11: error: use of undefined value here causes illegal behavior

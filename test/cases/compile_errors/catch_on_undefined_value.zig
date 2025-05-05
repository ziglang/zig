comptime {
    const a: anyerror!bool = undefined;
    if (a catch false) {}
}

// error
//
// :3:11: error: use of undefined value here causes illegal behavior

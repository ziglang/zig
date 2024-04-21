export fn entry() void {
    const x: error{}!u32 = 0;
    if (x) |v| v else |_| switch (_) {}
}

// error
// backend=stage2
// target=native
//
// :3:24: error: discard of error capture; omit it instead

test {
    const e: error{A}!u32 = error.A;
    if (e) |*ptr| {} else |err| switch (err) {}
}

// error
// backend=stage2
// target=native
//
// :3:14: error: unused capture

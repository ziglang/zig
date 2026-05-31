test {
    const e: error{A}!u32 = error.A;
    if (e) |*ptr| {} else |err| switch (err) {}
}

// error
//
// :3:14: error: unused capture

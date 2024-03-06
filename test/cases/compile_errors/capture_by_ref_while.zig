test {
    while (undefined) |*foo| {} else |err| {}
}

// error
// backend=stage2
// target=native
//
// :2:25: error: unused capture
// :2:39: error: unused capture
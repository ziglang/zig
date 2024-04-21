test {
    if (undefined) |*ident| {} else |err| {}
}

// error
// backend=stage2
// target=native
//
// :2:22: error: unused capture
// :2:38: error: unused capture

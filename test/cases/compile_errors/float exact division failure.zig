comptime {
    const x = @divExact(10.0, 3.0);
    _ = x;
}

// error
// backend=llvm
// target=native
//
// :2:15: error: exact division produced remainder

comptime {
    const x = @divExact(10, 3);
    _ = x;
}

// error
// backend=llvm
// target=native
//
// :2:15: error: exact division produced remainder

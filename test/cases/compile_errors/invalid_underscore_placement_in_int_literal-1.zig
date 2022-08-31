fn main() void {
    var bad: u128 = 10_;
    _ = bad;
}

// error
// backend=llvm
// target=native
//
// :2:23: error: trailing digit separator

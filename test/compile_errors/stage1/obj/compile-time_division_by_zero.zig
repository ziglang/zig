comptime {
    const a: i32 = 1;
    const b: i32 = 0;
    const c = a / b;
    _ = c;
}

// compile-time division by zero
//
// tmp.zig:4:17: error: division by zero

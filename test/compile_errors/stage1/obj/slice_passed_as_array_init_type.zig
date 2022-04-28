export fn entry() void {
    const x = []u8{};
    _ = x;
}

// error
// backend=stage1
// target=native
//
// tmp.zig:2:15: error: array literal requires address-of operator (&) to coerce to slice type '[]u8'

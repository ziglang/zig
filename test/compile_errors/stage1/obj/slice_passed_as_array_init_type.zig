export fn entry() void {
    const x = []u8{};
    _ = x;
}

// slice passed as array init type
//
// tmp.zig:2:15: error: array literal requires address-of operator (&) to coerce to slice type '[]u8'

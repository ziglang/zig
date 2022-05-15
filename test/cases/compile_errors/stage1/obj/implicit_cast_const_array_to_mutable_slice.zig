export fn entry() void {
    const buffer: [1]u8 = [_]u8{8};
    const sliceA: []u8 = &buffer;
    _ = sliceA;
}

// error
// backend=stage1
// target=native
//
// tmp.zig:3:27: error: cannot cast pointer to array literal to slice type '[]u8'
// tmp.zig:3:27: note: cast discards const qualifier

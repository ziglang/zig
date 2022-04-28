export fn entry() void {
    const u: u32 = 42;
    const x: []u32 = &u;
    _ = x;
}

// error
// backend=stage1
// target=native
//
// tmp.zig:3:23: error: expected type '[]u32', found '*const u32'

export fn entry() void {
    const u: u32 = 42;
    const x: []u32 = &u;
    _ = x;
}

// error
//
// :3:22: error: expected type '[]u32', found '*const u32'
// :3:22: note: cast discards const qualifier

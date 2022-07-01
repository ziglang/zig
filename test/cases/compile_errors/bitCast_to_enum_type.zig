export fn entry() void {
    const E = enum(u32) { a, b };
    const y = @bitCast(E, @as(u32, 3));
    _ = y;
}

// error
// backend=stage2
// target=native
//
// :3:24: error: cannot @bitCast to 'tmp.entry.E'
// :3:24: note: use @intToEnum for type coercion

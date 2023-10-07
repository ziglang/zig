pub export fn entry() void {
    const E = enum(u3) { a, b, c, _ };
    @compileLog(@as(E, @enumFromInt(100)));
}

// error
// target=native
// backend=stage2
//
// :3:24: error: int value '100' out of range of non-exhaustive enum 'tmp.entry.E'
// :2:15: note: enum declared here

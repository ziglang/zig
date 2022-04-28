export fn entry() void {
    const a = '\U1234';
}

// error
// backend=stage1
// target=native
//
// tmp.zig:2:15: error: expected expression, found 'invalid bytes'
// tmp.zig:2:18: note: invalid byte: '1'

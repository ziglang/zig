export fn entry() void {
    const a = '\U1234';
}

// invalid legacy unicode escape
//
// tmp.zig:2:15: error: expected expression, found 'invalid bytes'
// tmp.zig:2:18: note: invalid byte: '1'

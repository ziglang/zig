export fn entry() void {
    const a = '\U1234';
}

// error
// backend=stage2
// target=native
//
// :2:15: error: expected expression, found 'invalid bytes'
// :2:18: note: invalid byte: '1'

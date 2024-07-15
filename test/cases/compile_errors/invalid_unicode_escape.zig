export fn entry() void {
    const a = '\u{12z34}';
}

// error
// backend=stage2
// target=native
//
// :2:15: error: expected expression, found 'invalid bytes'
// :2:21: note: invalid byte: 'z'


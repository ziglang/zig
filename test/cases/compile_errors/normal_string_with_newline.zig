const foo = "a
b";

// error
// backend=stage2
// target=native
//
// :1:13: error: expected expression, found 'invalid bytes'
// :1:15: note: invalid byte: '\n'

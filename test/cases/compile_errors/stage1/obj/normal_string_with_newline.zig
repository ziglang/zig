const foo = "a
b";

// error
// backend=stage1
// target=native
//
// tmp.zig:1:13: error: expected expression, found 'invalid bytes'
// tmp.zig:1:15: note: invalid byte: '\n'

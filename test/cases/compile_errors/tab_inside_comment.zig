// Some		comment
export fn entry() void {}

// error
// backend=stage2
// target=native
//
// :1:1: error: expected 'a comment', found invalid bytes
// :1:8: note: invalid byte: '\t'

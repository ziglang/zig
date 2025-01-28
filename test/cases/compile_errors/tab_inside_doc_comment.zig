/// Some doc		comment
export fn entry() void {}

// error
// backend=stage2
// target=native
//
// :1:1: error: expected 'a document comment', found invalid bytes
// :1:13: note: invalid byte: '\t'

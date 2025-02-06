// Some		comment
export fn entry() void {}

// error
// backend=stage2
// target=native
//
// :1:8: error: comment contains invalid byte: '\t'

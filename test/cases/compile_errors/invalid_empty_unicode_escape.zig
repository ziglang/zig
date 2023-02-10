export fn entry() void {
    const a = '\u{}';
}

// error
// backend=stage2
// target=native
//
// :2:19: error: empty unicode escape sequence

export fn entry() void {
    const a = '\u{}';
}

// error
// backend=stage1
// target=native
//
// tmp.zig:2:19: error: empty unicode escape sequence

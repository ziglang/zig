export fn entry() void {
    const a = '\u{12z34}';
}

// error
// backend=stage2
// target=native
//
// :2:21: error: expected hex digit or '}', found 'z'


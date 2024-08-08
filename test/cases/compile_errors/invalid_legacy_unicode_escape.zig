export fn entry() void {
    const a = '\U1234';
}

// error
// backend=stage2
// target=native
//
// :2:17: error: invalid escape character: 'U'

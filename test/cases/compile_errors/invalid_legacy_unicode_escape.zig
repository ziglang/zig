export fn entry() void {
    const a = '\U1234';
}

// error
//
// :2:17: error: invalid escape character: 'U'

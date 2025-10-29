export fn f() void {
    (const a = 0);
}

// error
//
// :2:6: error: expected expression, found 'const'

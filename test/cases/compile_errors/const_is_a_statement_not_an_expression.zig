export fn f() void {
    (const a = 0);
}

// error
// backend=stage2
// target=native
//
// :2:6: error: expected expression, found 'const'

export fn f() void {
    (const a = 0);
}

// error
// backend=stage1
// target=native
//
// tmp.zig:2:6: error: expected expression, found 'const'

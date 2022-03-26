export fn f() void {
    (const a = 0);
}

// const is a statement, not an expression
//
// tmp.zig:2:6: error: expected expression, found 'const'

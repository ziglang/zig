pub const A = B;
export fn foo() void {
    _ = @typeInfo(@This()).@"struct".decls[0];
}

// error
//
// :1:15: error: use of undeclared identifier 'B'

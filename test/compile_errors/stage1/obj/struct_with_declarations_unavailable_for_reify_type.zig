export fn entry() void {
    _ = @Type(@typeInfo(struct { const foo = 1; }));
}

// error
// backend=stage1
// target=native
//
// tmp.zig:2:15: error: Type.Struct.decls must be empty for @Type

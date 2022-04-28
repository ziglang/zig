export fn entry() void {
    _ = @Type(@typeInfo(enum { foo, const bar = 1; }));
}

// error
// backend=stage1
// target=native
//
// tmp.zig:2:15: error: Type.Enum.decls must be empty for @Type

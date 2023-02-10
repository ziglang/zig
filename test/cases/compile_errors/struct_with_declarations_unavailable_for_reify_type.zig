export fn entry() void {
    _ = @Type(@typeInfo(struct { const foo = 1; }));
}

// error
// backend=stage2
// target=native
//
// :2:9: error: reified structs must have no decls

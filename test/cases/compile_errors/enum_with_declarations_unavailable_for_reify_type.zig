export fn entry() void {
    _ = @Type(@typeInfo(enum {
        foo,
        pub const bar = 1;
    }));
}

// error
// backend=stage2
// target=native
//
// :2:9: error: reified enums must have no decls

export fn entry() void {
    _ = @Type(@typeInfo(enum {
        foo,
        pub const bar = 1;
    }));
}

// error
//
// :2:9: error: reified enums must have no decls

export fn entry() void {
    _ = @Enum(@typeInfo(enum {
        foo,
        pub const bar = 1;
    }).@"enum");
}

// error
//
// :2:9: error: reified enums must have no decls

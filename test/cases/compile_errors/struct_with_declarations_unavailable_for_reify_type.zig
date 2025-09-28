export fn entry() void {
    _ = @Type(@typeInfo(struct {
        pub const foo = 1;
    }));
}

// error
//
// :2:9: error: reified structs must have no decls

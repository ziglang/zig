export fn entry() void {
    _ = @Struct(@typeInfo(struct {
        pub const foo = 1;
    }).@"struct");
}

// error
//
// :2:9: error: reified structs must have no decls

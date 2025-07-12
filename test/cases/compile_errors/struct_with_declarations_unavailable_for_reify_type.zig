export fn entry() void {
    _ = @Struct(@typeInfo(struct {
        pub const foo = 1;
    }).@"struct");
}

// error
// backend=stage2
// target=native
//
// :2:9: error: reified structs must have no decls

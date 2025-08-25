export fn entry() void {
    _ = @hasDecl(i32, "hi");
}

// error
// backend=stage2
// target=native
//
// :2:18: error: expected struct, enum, union, or opaque; found 'i32'

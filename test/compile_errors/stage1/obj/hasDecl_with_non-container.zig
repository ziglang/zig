export fn entry() void {
    _ = @hasDecl(i32, "hi");
}

// @hasDecl with non-container
//
// tmp.zig:2:18: error: expected struct, enum, or union; found 'i32'

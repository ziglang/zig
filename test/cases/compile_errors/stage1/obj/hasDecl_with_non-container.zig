export fn entry() void {
    _ = @hasDecl(i32, "hi");
}

// error
// backend=stage1
// target=native
//
// tmp.zig:2:18: error: expected struct, enum, or union; found 'i32'

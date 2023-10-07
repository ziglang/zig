export fn foo() void {
    _ = [2]u16{
        "hello",
        "world",
    };
}

// error
// backend=llvm
// target=native
//
// :3:9: error: expected type 'u16', found '*const [5:0]u8'

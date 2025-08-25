export fn foo() void {
    const x: [*][5]u8 = undefined;
    _ = x.len;
}

// error
// backend=stage2
// target=native
//
// :3:10: error: type '[*][5]u8' does not support field access

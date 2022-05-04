export fn foo() [*:0]const u8 {
    var buffer: [64]u8 = undefined;
    return buffer[0..];
}

// error
// backend=stage1
// target=native
//
// :3:18: error: expected type '[*:0]const u8', found '*[64]u8'
// :3:18: note: destination pointer requires a terminating '0' sentinel

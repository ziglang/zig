export fn foo() [*:0]const u8 {
    var buffer: [64]u8 = undefined;
    return buffer[0..];
}

// error
// backend=stage2
// target=native
//
// :3:18: error: expected type '[*:0]const u8', found '*[64]u8'
// :3:18: note: destination pointer requires '0' sentinel
// :1:18: note: function return type declared here

var global_buffer: [64]u8 = undefined;

export fn foo() [*:0]const u8 {
    return global_buffer[0..];
}

// error
//
// :4:25: error: expected type '[*:0]const u8', found '*[64]u8'
// :4:25: note: destination pointer requires '0' sentinel
// :3:17: note: function return type declared here

export fn foo() [*:0]const u8 {
    var buffer: [64]u8 = undefined;
    return buffer[0..];
}

// issue #4207: coerce from non-terminated-slice to terminated-pointer
//
// :3:18: error: expected type '[*:0]const u8', found '*[64]u8'
// :3:18: note: destination pointer requires a terminating '0' sentinel

export fn b() void {
    const ptr: [*:0]u8 = "foo";
    _ = ptr;
}

// error
//
// :2:26: error: expected type '[*:0]u8', found '*const [3:0]u8'
// :2:26: note: cast discards const qualifier

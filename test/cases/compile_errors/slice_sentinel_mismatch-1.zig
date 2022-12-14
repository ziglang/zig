export fn entry() void {
    const y: [:1]const u8 = &[_:2]u8{ 1, 2 };
    _ = y;
}

// error
// backend=stage2
// target=native
//
// :2:29: error: expected type '[:1]const u8', found '*const [2:2]u8'
// :2:29: note: pointer sentinel '2' cannot cast into pointer sentinel '1'

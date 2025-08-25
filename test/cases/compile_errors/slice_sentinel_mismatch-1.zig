export fn entry1() void {
    const y: [:1]const u8 = &[_:2]u8{ 1, 2 };
    _ = y;
}
export fn entry2() void {
    const x: [:2]const u8 = &.{ 1, 2 };
    const y: [:1]const u8 = x;
    _ = y;
}

// error
// backend=stage2
// target=native
//
// :2:37: error: expected type '[2:1]u8', found '[2:2]u8'
// :2:37: note: array sentinel '2' cannot cast into array sentinel '1'
// :7:29: error: expected type '[:1]const u8', found '[:2]const u8'
// :7:29: note: pointer sentinel '2' cannot cast into pointer sentinel '1'

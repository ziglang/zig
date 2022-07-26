export fn entry() void {
    const ints = [_]u8{ 1, 2 };
    inline for (ints) |_| {
        bad() orelse continue;
    }
}
fn bad() ?void {
    return null;
}

// error
// backend=stage2
// target=native
//
// :4:22: error: comptime control flow inside runtime block
// :4:15: note: runtime control flow here

export fn a() void {
    const x: *fn () void = @ptrFromInt(4);
    x.* = undefined;
}

export fn b(x: *anyopaque) void {
    x.* = undefined;
}

// error
// backend=stage2
// target=native
//
// :3:6: error: pointer element type must have a comptime-known size
// :7:6: error: pointer element type must have a comptime-known size

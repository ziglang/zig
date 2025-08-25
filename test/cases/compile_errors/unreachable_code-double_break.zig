export fn a() void {
    const b = blk: {
        break :blk break :blk @as(u32, 1);
    };
    _ = b;
}

// error
// backend=stage2
// target=native
//
// :3:9: error: unreachable code
// :3:20: note: control flow is diverted here

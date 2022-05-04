export fn a() void {
    const b = blk: {
        break :blk break :blk @as(u32, 1);
    };
}

// error
// backend=stage1
// target=native
//
// tmp.zig:3:9: error: unreachable code
// tmp.zig:3:20: note: control flow is diverted here

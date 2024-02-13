var frame: ?anyframe = null;

export fn a() void {
    _ = async rangeSum(10);
    while (frame) |f| resume f;
}

fn rangeSum(x: i32) i32 {
    suspend {
        frame = @frame();
    }
    frame = null;

    if (x == 0) return 0;
    const child = rangeSumIndirect(x - 1);
    return child + 1;
}

fn rangeSumIndirect(x: i32) i32 {
    suspend {
        frame = @frame();
    }
    frame = null;

    if (x == 0) return 0;
    const child = rangeSum(x - 1);
    return child + 1;
}

// error
// backend=stage1
// target=native
//
// tmp.zig:8:1: error: '@Frame(rangeSum)' depends on itself
// tmp.zig:15:35: note: when analyzing type '@Frame(rangeSum)' here
// tmp.zig:28:25: note: when analyzing type '@Frame(rangeSumIndirect)' here

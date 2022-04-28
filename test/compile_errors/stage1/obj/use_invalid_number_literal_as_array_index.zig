var v = 25;
export fn entry() void {
    var arr: [v]u8 = undefined;
    _ = arr;
}

// error
// backend=stage1
// target=native
//
// tmp.zig:1:1: error: unable to infer variable type

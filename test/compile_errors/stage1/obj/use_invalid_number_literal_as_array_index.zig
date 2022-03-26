var v = 25;
export fn entry() void {
    var arr: [v]u8 = undefined;
    _ = arr;
}

// use invalid number literal as array index
//
// tmp.zig:1:1: error: unable to infer variable type

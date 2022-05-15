export fn entry() void {
    var a: []u8 = undefined;
    _ = a.*.len;
}

// error
// backend=stage1
// target=native
//
// tmp.zig:3:10: error: attempt to dereference non-pointer type '[]u8'

export fn entry() void {
    var a: []u8 = undefined;
    _ = a.*.len;
    _ = &a;
}

// error
// backend=stage2
// target=native
//
// :3:10: error: index syntax required for slice type '[]u8'

export fn entry() void {
    var a: []u8 = undefined;
    _ = a.*.len;
}

// deref slice and get len field
//
// tmp.zig:3:10: error: attempt to dereference non-pointer type '[]u8'

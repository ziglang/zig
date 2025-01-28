export fn entry() void {
    const f: *struct { u8, u8, u8 } = @import("zon/array.zon");
    _ = f;
}

// error
// imports=zon/array.zon
//
// array.zon:1:2: error: non slice pointers are not available in ZON
// tmp.zig:2:47: note: imported here

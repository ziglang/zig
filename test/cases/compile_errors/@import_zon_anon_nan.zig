export fn entry() void {
    _ = @import("zon/nan.zon");
}

// error
// imports=zon/nan.zon
//
// nan.zon:1:1: error: NaN requires a known result type
// tmp.zig:2:17: note: imported here

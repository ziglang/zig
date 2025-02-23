export fn entry() void {
    const f: comptime_float = @import("zon/nan.zon");
    _ = f;
}

// error
// imports=zon/nan.zon
//
// nan.zon:1:1: error: expected type 'comptime_float'
// tmp.zig:2:39: note: imported here

export fn entry() void {
    const f: comptime_float = @import("zon/inf.zon");
    _ = f;
}

// error
// imports=zon/inf.zon
//
// inf.zon:1:1: error: expected type 'comptime_float'
// tmp.zig:2:39: note: imported here

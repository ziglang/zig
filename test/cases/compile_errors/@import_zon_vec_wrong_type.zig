export fn entry() void {
    const f: @Vector(2, bool) = @import("zon/tuple.zon");
    _ = f;
}

// error
// imports=zon/tuple.zon
//
// tuple.zon:1:4: error: expected type 'bool'
// tmp.zig:2:41: note: imported here

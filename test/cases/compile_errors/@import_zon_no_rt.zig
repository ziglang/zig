export fn entry() void {
    const f = @import("zon/simple_union.zon");
    _ = f;
}

// error
// imports=zon/simple_union.zon
//
// tmp.zig:2:23: error: '@import' of ZON must have a known result type

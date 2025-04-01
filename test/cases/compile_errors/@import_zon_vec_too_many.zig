export fn entry() void {
    const f: @Vector(1, f32) = @import("zon/tuple.zon");
    _ = f;
}

// error
// imports=zon/tuple.zon
//
// tuple.zon:1:2: error: expected 1 vector elements; found 2
// tmp.zig:2:40: note: imported here

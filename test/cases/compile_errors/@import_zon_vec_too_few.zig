export fn entry() void {
    const f: @Vector(3, f32) = @import("zon/tuple.zon");
    _ = f;
}

// error
// imports=zon/tuple.zon
//
// tuple.zon:1:2: error: expected 3 vector elements; found 2
// tmp.zig:2:40: note: imported here

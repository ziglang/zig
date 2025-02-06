export fn entry() void {
    const Vec2 = struct {
        comptime x: f32 = 1.5,
        comptime y: f32 = 2.5,
    };
    const f: Vec2 = @import("zon/vec2.zon");
    _ = f;
}

// error
// imports=zon/vec2.zon
//
// vec2.zon:1:19: error: value stored in comptime field does not match the default value of the field
// tmp.zig:6:29: note: imported here

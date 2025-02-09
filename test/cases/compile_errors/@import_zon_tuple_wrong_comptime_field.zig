export fn entry() void {
    const T = struct {
        comptime f32 = 1.5,
        comptime f32 = 2.5,
    };
    const f: T = @import("zon/tuple.zon");
    _ = f;
}

// error
// imports=zon/tuple.zon
//
// tuple.zon:1:9: error: value stored in comptime field does not match the default value of the field
// tmp.zig:6:26: note: imported here

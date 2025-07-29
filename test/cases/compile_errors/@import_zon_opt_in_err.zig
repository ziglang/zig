export fn testFloatA() void {
    const f: ?f32 = @import("zon/vec2.zon");
    _ = f;
}

export fn testFloatB() void {
    const f: *const ?f32 = @import("zon/vec2.zon");
    _ = f;
}

export fn testFloatC() void {
    const f: ?*const f32 = @import("zon/vec2.zon");
    _ = f;
}

export fn testBool() void {
    const f: ?bool = @import("zon/vec2.zon");
    _ = f;
}

export fn testInt() void {
    const f: ?i32 = @import("zon/vec2.zon");
    _ = f;
}

const Enum = enum { foo };
export fn testEnum() void {
    const f: ?Enum = @import("zon/vec2.zon");
    _ = f;
}

export fn testEnumLit() void {
    const f: ?@TypeOf(.foo) = @import("zon/vec2.zon");
    _ = f;
}

export fn testArray() void {
    const f: ?[1]u8 = @import("zon/vec2.zon");
    _ = f;
}

const Union = union {};
export fn testUnion() void {
    const f: ?Union = @import("zon/vec2.zon");
    _ = f;
}

export fn testSlice() void {
    const f: ?[]const u8 = @import("zon/vec2.zon");
    _ = f;
}

export fn testVector() void {
    const f: ?@Vector(3, f32) = @import("zon/vec2.zon");
    _ = f;
}

// error
// imports=zon/vec2.zon
//
// vec2.zon:1:2: error: expected type '?f32'
// tmp.zig:2:29: note: imported here
// vec2.zon:1:2: error: expected type '*const ?f32'
// tmp.zig:7:36: note: imported here
// vec2.zon:1:2: error: expected type '?*const f32'
// tmp.zig:12:36: note: imported here
// vec2.zon:1:2: error: expected type '?bool'
// tmp.zig:17:30: note: imported here
// vec2.zon:1:2: error: expected type '?i32'
// tmp.zig:22:29: note: imported here
// vec2.zon:1:2: error: expected type '?tmp.Enum'
// tmp.zig:28:30: note: imported here
// vec2.zon:1:2: error: expected type '?@Type(.enum_literal)'
// tmp.zig:33:39: note: imported here
// vec2.zon:1:2: error: expected type '?[1]u8'
// tmp.zig:38:31: note: imported here
// vec2.zon:1:2: error: expected type '?tmp.Union'
// tmp.zig:44:31: note: imported here
// vec2.zon:1:2: error: expected type '?[]const u8'
// tmp.zig:49:36: note: imported here
// vec2.zon:1:2: error: expected type '?@Vector(3, f32)'
// tmp.zig:54:41: note: imported here

export fn entry() void {
    const V1 = @import("std").meta.Vector(4, u8);
    const V2 = @Type(.{ .Vector = .{ .len = 4, .child = V1 } });
    var v: V2 = undefined;
    _ = v;
}

// nested vectors
//
// tmp.zig:3:23: error: vector element type must be integer, float, bool, or pointer; '@Vector(4, u8)' is invalid

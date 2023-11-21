export fn entry() void {
    const V1 = @Vector(4, u8);
    const V2 = @Type(.{ .Vector = .{ .len = 4, .child = V1 } });
    const v: V2 = undefined;
    _ = v;
}

// error
// backend=stage2
// target=native
//
// :3:16: error: expected integer, float, bool, or pointer for the vector element type; found '@Vector(4, u8)'

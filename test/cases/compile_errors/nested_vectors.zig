export fn entry() void {
    const V1 = @Vector(4, u8);
    const V2 = @Vector(4, V1);
    const v: V2 = undefined;
    _ = v;
}

// error
//
// :3:27: error: expected integer, float, bool, or pointer for the vector element type; found '@Vector(4, u8)'

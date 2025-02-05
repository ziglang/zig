export fn entry() void {
    const a = @Vector(4, u32){ 1, 1, 1, 1 };
    _ = @as(u32, @intCast(a));
}

// error
//
// :3:27: error: expected type 'u32', found '@Vector(4, u32)'

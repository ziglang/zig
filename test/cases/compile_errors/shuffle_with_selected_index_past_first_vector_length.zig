export fn entry() void {
    const v: @Vector(4, u32) = [4]u32{ 10, 11, 12, 13 };
    const x: @Vector(4, u32) = [4]u32{ 14, 15, 16, 17 };
    const z = @shuffle(u32, v, x, [8]i32{ 0, 1, 2, 3, 7, 6, 5, 4 });
    _ = z;
}

// error
// backend=stage2
// target=native
//
// :4:41: error: mask index '4' has out-of-bounds selection
// :4:29: note: selected index '7' out of bounds of '@Vector(4, u32)'
// :4:32: note: selections from the second vector are specified with negative numbers

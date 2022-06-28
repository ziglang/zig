export fn entry() void {
    const v: @import("std").meta.Vector(4, u32) = [4]u32{ 10, 11, 12, 13 };
    const x: @import("std").meta.Vector(4, u32) = [4]u32{ 14, 15, 16, 17 };
    var z = @shuffle(u32, v, x, [8]i32{ 0, 1, 2, 3, 7, 6, 5, 4 });
    _ = z;
}

// error
// backend=stage2
// target=native
//
// :4:39: error: mask index '4' has out-of-bounds selection
// :4:27: note: selected index '7' out of bounds of '@Vector(4, u32)'
// :4:30: note: selections from the second vector are specified with negative numbers

export fn entry() void {
    const x = @import("std").meta.Vector(3, f32){ 25, 75, 5, 0 };
    _ = x;
}

// error
// backend=stage2
// target=native
//
// :2:49: error: expected 3 vector elements; found 4

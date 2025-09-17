export fn entry() void {
    const x = @Vector(3, f32){ 25, 75, 5, 0 };
    _ = x;
}

// error
//
// :2:30: error: expected 3 vector elements; found 4

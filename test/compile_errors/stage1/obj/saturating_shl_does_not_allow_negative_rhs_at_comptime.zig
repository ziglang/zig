export fn a() void {
    _ = @as(i32, 1) <<| @as(i32, -2);
}

// saturating shl does not allow negative rhs at comptime
//
// error: shift by negative value -2

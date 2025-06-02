export fn foo() void {
    // Here, the bad index ('7') is not less than 'b.len', so the error shouldn't have a note suggesting a negative index.
    const a: @Vector(4, u32) = .{ 10, 11, 12, 13 };
    const b: @Vector(4, u32) = .{ 14, 15, 16, 17 };
    _ = @shuffle(u32, a, b, [8]i32{ 0, 1, 2, 3, 7, 6, 5, 4 });
}
export fn bar() void {
    // Here, the bad index ('7') *is* less than 'b.len', so the error *should* have a note suggesting a negative index.
    const a: @Vector(4, u32) = .{ 10, 11, 12, 13 };
    const b: @Vector(9, u32) = .{ 14, 15, 16, 17, 18, 19, 20, 21, 22 };
    _ = @shuffle(u32, a, b, [8]i32{ 0, 1, 2, 3, 7, 6, 5, 4 });
}

// error
//
// :5:35: error: mask element at index '4' selects out-of-bounds index
// :5:23: note: index '7' exceeds bounds of '@Vector(4, u32)' given here
// :11:35: error: mask element at index '4' selects out-of-bounds index
// :11:23: note: index '7' exceeds bounds of '@Vector(4, u32)' given here
// :11:26: note: use '~@as(u32, 7)' to index into second vector given here

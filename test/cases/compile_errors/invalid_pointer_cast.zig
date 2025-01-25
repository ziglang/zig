export fn foo() void {
    const slice: []const u8 = &.{ 1, 2, 3 };
    const result: [*]const u8 = @alignCast(slice);
    _ = result;
}

// error
//
// :3:33: error: cannot implicitly convert slice to many pointer
// :3:33: note: use 'ptr' field to convert slice to many pointer

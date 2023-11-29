pub fn sort(
    comptime T: type,
    items: []T,
    context: anytype,
    lessThan: *const fn (context: @TypeOf(context), lhs: T, rhs: T) u32,
) void {
    _ = items;
    _ = lessThan;
}
fn foo(_: void, _: u8, _: u8) u32 {
    return 0;
}
pub export fn entry() void {
    var items = [_]u8{ 3, 5, 7, 2, 6, 9, 4 };
    sort(u8, &items, void, foo);
}

// error
// backend=llvm
// target=native
//
// :15:28: error: expected type '*const fn (comptime type, u8, u8) u32', found '*const fn (void, u8, u8) u32'
// :15:28: note: pointer type child 'fn (void, u8, u8) u32' cannot cast into pointer type child 'fn (comptime type, u8, u8) u32'
// :15:28: note: non-generic function cannot cast into a generic function

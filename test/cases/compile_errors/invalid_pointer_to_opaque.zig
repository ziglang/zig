export fn a() void {
    _ = []anyopaque;
}
export fn b() void {
    _ = [*]anyopaque;
}
export fn c() void {
    _ = [*c]anyopaque;
}

export fn d() void {
    _ = @Type(.{ .pointer = .{
        .size = .slice,
        .is_const = false,
        .is_volatile = false,
        .alignment = 1,
        .address_space = .generic,
        .child = anyopaque,
        .is_allowzero = false,
        .sentinel_ptr = null,
    } });
}
export fn e() void {
    _ = @Type(.{ .pointer = .{
        .size = .many,
        .is_const = false,
        .is_volatile = false,
        .alignment = 1,
        .address_space = .generic,
        .child = anyopaque,
        .is_allowzero = false,
        .sentinel_ptr = null,
    } });
}
export fn f() void {
    _ = @Type(.{ .pointer = .{
        .size = .c,
        .is_const = false,
        .is_volatile = false,
        .alignment = 1,
        .address_space = .generic,
        .child = anyopaque,
        .is_allowzero = false,
        .sentinel_ptr = null,
    } });
}

// error
//
// :2:11: error: indexable pointer to opaque type 'anyopaque' not allowed
// :5:12: error: indexable pointer to opaque type 'anyopaque' not allowed
// :8:13: error: indexable pointer to opaque type 'anyopaque' not allowed
// :12:9: error: indexable pointer to opaque type 'anyopaque' not allowed
// :24:9: error: indexable pointer to opaque type 'anyopaque' not allowed
// :36:9: error: indexable pointer to opaque type 'anyopaque' not allowed

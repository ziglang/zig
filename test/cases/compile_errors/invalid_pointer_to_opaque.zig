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
    _ = @Pointer(.slice, .{}, anyopaque, null);
}
export fn e() void {
    _ = @Pointer(.many, .{}, anyopaque, null);
}
export fn f() void {
    _ = @Pointer(.c, .{}, anyopaque, null);
}

// error
//
// :2:11: error: indexable pointer to opaque type 'anyopaque' not allowed
// :5:12: error: indexable pointer to opaque type 'anyopaque' not allowed
// :8:13: error: indexable pointer to opaque type 'anyopaque' not allowed
// :12:9: error: indexable pointer to opaque type 'anyopaque' not allowed
// :15:9: error: indexable pointer to opaque type 'anyopaque' not allowed
// :18:9: error: indexable pointer to opaque type 'anyopaque' not allowed

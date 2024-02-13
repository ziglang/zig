export fn entry() void {
    const Tag = enum(comptime_int) { a, b };

    var v: u32 = 0;
    _ = &v;
    _ = @as(Tag, @enumFromInt(v));
}

// error
// backend=stage2
// target=native
//
// :6:31: error: unable to resolve comptime value
// :6:31: note: value being casted to enum with 'comptime_int' tag type must be comptime-known

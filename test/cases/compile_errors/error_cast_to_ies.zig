comptime {
    b();
}

fn a() !void {
    return;
}

fn b() void {
    _ = @as(@TypeOf(a()), @errorCast(error.Err));
}

// error
// backend=stage2
// target=native
//
// :10:27: error: 'error.Err' not a member of error set '@typeInfo(@typeInfo(@TypeOf(tmp.a)).@"fn".return_type.?).error_union.error_set'
// :2:6: note: called from here

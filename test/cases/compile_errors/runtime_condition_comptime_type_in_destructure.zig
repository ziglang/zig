export fn foobar() void {
    var t = true;
    _ = &t;
    const a, _ = if (t) .{ .a, {} } else .{ .b, {} };
    _ = a;
}

// error
//
// :4:5: error: value with comptime-only type '@EnumLiteral()' depends on runtime control flow

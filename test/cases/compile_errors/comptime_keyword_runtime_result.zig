var global_rt: u8 = 123;

export fn foo() void {
    _ = comptime global_rt;
}

export fn bar(rt: ?*anyopaque) void {
    if (rt != null) bar(comptime rt);
}

// error
//
// :4:18: error: unable to resolve comptime value
// :8:34: error: unable to resolve comptime value

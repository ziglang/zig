const GuSettings = struct {
    fin: ?fn (c_int) callconv(.C) void,
};
pub export fn callbackFin(id: c_int, arg: ?*anyopaque) void {
    const settings: ?*GuSettings = @as(?*GuSettings, @ptrFromInt(@intFromPtr(arg)));
    if (settings.?.fin != null) {
        settings.?.fin.?(id & 0xffff);
    }
}

// error
// target=native
//
// :5:54: error: pointer to comptime-only type '?*tmp.GuSettings' must be comptime-known, but operand is runtime-known
// :2:10: note: struct requires comptime because of this field
// :2:10: note: use '*const fn (c_int) callconv(.C) void' for a function pointer type

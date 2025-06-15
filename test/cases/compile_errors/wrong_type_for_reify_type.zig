export fn entryE() void {
    _ = @Enum(0);
}

export fn entryS() void {
    _ = @Struct(0);
}

export fn entryU() void {
    _ = @Union(0);
}

// error
// backend=stage2
// target=native
//
// :2:15: error: expected type 'builtin.Type.Enum', found 'comptime_int'
// :?:?: note: struct declared here
// :6:17: error: expected type 'builtin.Type.Struct', found 'comptime_int'
// :?:?: note: struct declared here
// :10:16: error: expected type 'builtin.Type.Union', found 'comptime_int'
// :?:?: note: struct declared here

export fn entryI() void {
    _ = @Int(0, 0);
}

export fn entryE() void {
    _ = @Enum(0, 0, 0, 0);
}

export fn entryS() void {
    _ = @Struct(0, 0, &.{}, &.{}, &.{});
}

export fn entryU() void {
    _ = @Union(0, 0, &.{}, &.{}, &.{});
}

// error
//
// :2:14: error: expected type 'builtin.Signedness', found 'comptime_int'
// :?:?: note: enum declared here
// :6:15: error: expected type 'type', found 'comptime_int'
// :10:17: error: expected type 'builtin.Type.ContainerLayout', found 'comptime_int'
// :?:?: enum declared here
// :14:16: error: expected type 'builtin.Type.ContainerLayout', found 'comptime_int'
// :?:?: enum declared here

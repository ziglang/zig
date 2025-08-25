export fn entry() void {
    _ = @Type(0);
}

// error
// backend=stage2
// target=native
//
// :2:15: error: expected type 'builtin.Type', found 'comptime_int'
// :?:?: note: union declared here

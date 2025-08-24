fn comptimeArray(comptime _: []const u8) void {}
fn bar() u8 {
    return 123;
}
export fn entry() void {
    const y = bar();
    comptimeArray(&.{y});
}

// error
//
// :7:19: error: unable to resolve comptime value
// :7:19: note: argument to comptime parameter must be comptime-known
// :1:18: note: parameter declared comptime here

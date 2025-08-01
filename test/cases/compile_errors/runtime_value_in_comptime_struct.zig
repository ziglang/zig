fn comptimeStruct(comptime _: anytype) void {}
fn bar() u8 {
    return 123;
}
export fn entry() void {
    const y = bar();
    comptimeStruct(.{ .foo = y });
}

// error
//
// :7:21: error: unable to resolve comptime value
// :7:21: note: argument to comptime parameter must be comptime-known
// :1:19: note: parameter declared comptime here

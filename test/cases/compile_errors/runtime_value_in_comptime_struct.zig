fn comptimeStruct(comptime _: anytype) void {}
fn bar() u8 {
    return 123;
}

pub fn main() void {
    const y = bar();
    comptimeStruct(.{ .foo = y });
}

// error
//
// :8:21: error: unable to evaluate comptime expression
// :8:24: note: operation is runtime due to this operand
// :8:21: note: argument to comptime parameter must be comptime-known
// :1:19: note: parameter declared comptime here

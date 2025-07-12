fn comptimeArray(comptime _: []const u8) void {}
fn bar() u8 {
    return 123;
}

pub fn main() void {
    const y = bar();
    comptimeArray(&.{y});
}

// error
//
// :8:21: error: unable to evaluate comptime expression
// :8:22: note: operation is runtime due to this operand
// :8:19: note: argument to comptime parameter must be comptime-known
// :1:18: note: parameter declared comptime here

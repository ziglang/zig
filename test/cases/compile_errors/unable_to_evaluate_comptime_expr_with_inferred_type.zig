const A = struct {
    a: u8,
};

var n: u8 = 5;
var a: A = .{ .a = n };

pub export fn entry() void {
    _ = a;
}

// error
// backend=stage2
// target=native
//
// :6:13: error: unable to evaluate comptime expression
// :6:16: note: operation is runtime due to this operand

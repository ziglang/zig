var n: u8 = 5;

const S = struct {
    a: u8,
};

var a: S = .{ .a = n };

pub export fn entry1() void {
    _ = a;
}

var b: S = S{ .a = n };

pub export fn entry2() void {
    _ = b;
}

// error
// backend=stage2
// target=native
//
// :7:13: error: unable to evaluate comptime expression
// :7:16: note: operation is runtime due to this operand
// :13:13: error: unable to evaluate comptime expression
// :13:16: note: operation is runtime due to this operand

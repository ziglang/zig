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

const Int = @typeInfo(bar).@"struct".backing_integer.?;

const foo = enum(Int) {
    c = @bitCast(bar{
        .name = "test",
    }),
};

const bar = packed struct {
    name: [*:0]const u8,
};

pub export fn entry3() void {
    _ = @field(foo, "c");
}

// error
// backend=stage2
// target=native
//
// :7:13: error: unable to evaluate comptime expression
// :7:16: note: operation is runtime due to this operand
// :13:13: error: unable to evaluate comptime expression
// :13:16: note: operation is runtime due to this operand
// :22:9: error: unable to evaluate comptime expression
// :22:21: note: operation is runtime due to this operand
